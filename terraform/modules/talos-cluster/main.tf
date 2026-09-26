terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
    talos = {
      source = "siderolabs/talos"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

locals {
  endpoint = "https://${var.vip}:6443"

  ips = { for name, node in var.nodes : name => split("/", node.ip)[0] }

  # Everything else comes from the name, e.g. prx-002-srv-prod-core-worker-001
  # is a worker on prx-002 in the worker-001 pool.
  hosts = { for name in keys(var.nodes) : name => regex("^(prx-[0-9]+)-", name)[0] }
  roles = { for name in keys(var.nodes) : name => can(regex("-control-[0-9]+$", name)) ? "controlplane" : "worker" }
  pools = { for name in keys(var.nodes) : name => regex("(worker-[0-9]+)$", name)[0] if local.roles[name] == "worker" }

  # The zone is the hypervisor, so pods can be spread across Proxmox nodes with
  # topologySpreadConstraints/podAntiAffinity on topology.kubernetes.io/zone.
  labels = {
    for name, node in var.nodes : name => merge(
      { "topology.kubernetes.io/zone" = local.hosts[name] },
      contains(keys(local.pools), name) ? { "${var.domain}/pool" = local.pools[name] } : {},
      # Used with Longhorn's create-default-disk-labeled-nodes setting.
      node.longhorn_disk != null ? { "node.longhorn.io/create-default-disk" = "true" } : {},
      node.labels,
    )
  }

  control_planes    = sort([for name in keys(var.nodes) : name if local.roles[name] == "controlplane"])
  control_plane_ips = [for name in local.control_planes : local.ips[name]]

  # Without workers everything has to run on the control plane.
  schedule_on_control_planes = length(local.control_planes) == length(var.nodes)
}

# -----------------------------------------------------
# VMs
# -----------------------------------------------------

resource "proxmox_virtual_environment_vm" "node" {
  for_each = var.nodes

  name        = each.key
  node_name   = local.hosts[each.key]
  vm_id       = each.value.vmid
  tags        = ["talos", var.context, local.roles[each.key]]
  description = "Talos ${local.roles[each.key]} for ${var.name}, managed by iac-homelab."

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"

  on_boot         = true
  stop_on_destroy = true

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  # The installer image from UnattendedInstallConfig expects this to be /dev/sda.
  disk {
    datastore_id = var.vm_datastore
    file_id      = var.image_file_ids[local.hosts[each.key]]
    interface    = "scsi0"
    file_format  = "raw"
    size         = each.value.disk
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  # Longhorn's data disk (/dev/sdb), see the longhorn UserVolumeConfig.
  dynamic "disk" {
    for_each = each.value.longhorn_disk != null ? [each.value.longhorn_disk] : []

    content {
      datastore_id = var.vm_datastore
      interface    = "scsi1"
      file_format  = "raw"
      size         = disk.value
      iothread     = true
      discard      = "on"
      ssd          = true
    }
  }

  network_device {
    bridge  = var.bridge
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  operating_system {
    type = "l26"
  }

  # Read by Talos's nocloud platform for the static IP.
  initialization {
    datastore_id = var.vm_datastore

    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = var.gateway
      }
    }

    dns {
      domain  = var.domain
      servers = var.nameservers
    }
  }

  lifecycle {
    # The image is only used for the first boot, Talos upgrades itself in place.
    ignore_changes = [disk[0].file_id]
  }
}

# -----------------------------------------------------
# Talos
# -----------------------------------------------------

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_contract
}

data "talos_machine_configuration" "node" {
  for_each = var.nodes

  cluster_name       = var.name
  cluster_endpoint   = local.endpoint
  machine_type       = local.roles[each.key]
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  talos_version      = var.talos_contract
  kubernetes_version = var.kubernetes_version

  config_patches = concat(
    [
      yamlencode({
        machine = {
          certSANs = ["${each.key}.${var.domain}", local.ips[each.key]]
        }
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "HostnameConfig"
        auto       = { "$patch" = "delete" }
        hostname   = each.key
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UnattendedInstallConfig"
        installer = {
          image = var.installer_image
        }
        provisioning = {
          diskSelector = {
            match = "disk.dev_path == \"/dev/sda\""
          }
        }
      }),
      yamlencode(merge(
        {
          apiVersion = "v1alpha1"
          kind       = "KubeNodeConfig"
          labels     = local.labels[each.key]
        },
        local.roles[each.key] == "controlplane" && local.schedule_on_control_planes ? {
          taints = { "node-role.kubernetes.io/control-plane" = { "$patch" = "delete" } }
        } : {}
      )),
      # Also set via cloud-init for first boot, this lets nameserver changes apply without a reboot.
      yamlencode({
        apiVersion  = "v1alpha1"
        kind        = "ResolverConfig"
        nameservers = [for address in var.nameservers : { address = address }]
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "LinkAliasConfig"
        name       = "net0"
        selector = {
          match = "link.driver == \"virtio_net\""
        }
      }),
    ],
    local.roles[each.key] == "controlplane" ? [
      yamlencode({
        apiVersion    = "v1alpha1"
        kind          = "KubeAPIServerConfig"
        certExtraSANs = concat([var.vip], [for name in local.control_planes : "${name}.${var.domain}"])
      }),
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "Layer2VIPConfig"
        name       = var.vip
        link       = "net0"
      }),
    ] : [],
    # Keeps Longhorn's replicas off the system disk, so a full volume can't cause evictions.
    # User volumes are mounted under /var/mnt, which the kubelet already has, so it needs
    # no extraMounts (they can't be set anyway, .machine.kubelet conflicts with KubeletConfig).
    each.value.longhorn_disk != null ? [
      yamlencode({
        apiVersion = "v1alpha1"
        kind       = "UserVolumeConfig"
        name       = "longhorn"
        provisioning = {
          diskSelector = {
            match = "disk.dev_path == \"/dev/sdb\""
          }
          minSize = "1GiB"
          grow    = true
        }
      }),
    ] : []
  )
}

# Only used to drain nodes during OS upgrades.
ephemeral "talos_cluster_kubeconfig" "this" {
  machine_secrets = talos_machine_secrets.this.machine_secrets
  cluster_name    = var.name
  endpoint        = local.endpoint
}

# Applies the config (installing from maintenance mode on first boot) and upgrades
# the OS when installer_image changes. Use -parallelism=1 so nodes upgrade one at a time.
resource "talos_machine" "node" {
  for_each = var.nodes

  node                  = local.ips[each.key]
  client_configuration  = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.node[each.key].machine_configuration
  image                 = var.installer_image

  # Nowhere to drain to with a single node.
  drain_on_upgrade = length(var.nodes) > 1
  kubeconfig_wo    = length(var.nodes) > 1 ? ephemeral.talos_cluster_kubeconfig.this.kubeconfig_raw : null

  # Kubernetes upgrades are owned by talos_cluster.
  ignore_kubernetes_upgrade_drift = true

  depends_on = [proxmox_virtual_environment_vm.node]
}

# Bootstraps etcd and upgrades Kubernetes when kubernetes_version changes.
resource "talos_cluster" "this" {
  node                 = local.control_plane_ips[0]
  control_plane_nodes  = local.control_plane_ips
  client_configuration = talos_machine_secrets.this.client_configuration
  kubernetes_version   = var.kubernetes_version

  depends_on = [talos_machine.node]
}

data "talos_client_configuration" "this" {
  cluster_name         = var.name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = local.control_plane_ips
  nodes                = [for name in sort(keys(var.nodes)) : local.ips[name]]
}

resource "local_sensitive_file" "talosconfig" {
  content         = data.talos_client_configuration.this.talos_config
  filename        = var.talosconfig_path
  file_permission = "0600"
}
