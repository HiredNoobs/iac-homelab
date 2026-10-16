locals {
  # VMs are prefixed with the Proxmox node they run on, e.g. prx-001-srv-... -> prx-001
  proxmox_nodes = distinct(flatten([
    for cluster in values(var.clusters) : [
      for name in keys(cluster.nodes) : regex("^(prx-[0-9]+)-", name)[0]
    ]
  ]))
}

# -----------------------------------------------------
# Talos image
# -----------------------------------------------------

data "talos_image_factory_extensions_versions" "this" {
  talos_version = var.talos_version
  filters = {
    names = var.talos_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = data.talos_image_factory_extensions_versions.this.extensions_info[*].name
      }
      # No dashboard on the VMs' consoles: it polls machined every few seconds, a log line per
      # call. `talosctl dashboard` (from mgmt) is unaffected. The console shows Talos' and the
      # kernel's messages instead.
      extraKernelArgs = ["talos.dashboard.disabled=1"]
    }
  })
}

data "talos_image_factory_urls" "this" {
  talos_version     = var.talos_version
  schematic_id      = talos_image_factory_schematic.this.id
  platform          = "nocloud"
  disk_image_format = "qcow2"
}

# Only used to create VMs, upgrades are done in place by talos_machine.
resource "proxmox_download_file" "talos" {
  for_each = toset(local.proxmox_nodes)

  node_name    = each.key
  content_type = "iso"
  datastore_id = var.image_datastore
  file_name    = "talos-${var.talos_version}-${substr(talos_image_factory_schematic.this.id, 0, 8)}-nocloud-amd64.img"
  url          = data.talos_image_factory_urls.this.urls.disk_image
  overwrite    = false
}

# -----------------------------------------------------
# Clusters
# -----------------------------------------------------

module "cluster" {
  source   = "../modules/talos-cluster"
  for_each = var.clusters

  context = each.key
  name    = each.value.name
  vip     = each.value.vip
  nodes   = each.value.nodes

  domain      = var.domain
  gateway     = var.gateway
  nameservers = var.nameservers
  bridge      = var.bridge
  vlan_id     = var.vlan_id

  vm_datastore   = var.vm_datastore
  image_file_ids = { for node, file in proxmox_download_file.talos : node => file.id }

  installer_image    = data.talos_image_factory_urls.this.urls.installer
  talos_contract     = var.talos_contract
  kubernetes_version = var.kubernetes_version
}

# -----------------------------------------------------
# Metrics
# -----------------------------------------------------

# Every prx-00x host's own and its guests' and storages' stats, pushed by pvestatd every 10
# seconds as InfluxDB lines to the cluster's vmagent (iac-k8s apps/base/monitoring/vmagent,
# metrics.hirednoobs.com only lets the hosts' addresses through). One setting for the whole
# Proxmox cluster (/etc/pve/status.cfg), the same as prx-999's (the gitops root): no token, org
# and bucket only because the v2 API's URL needs them, the /influx prefix is where vmagent has
# both the writes and the health check Proxmox makes when the server is added or changed. While
# the Kubernetes cluster is down the stats are lost.
resource "proxmox_metrics_server" "vmagent" {
  name   = "vmagent"
  type   = "influxdb"
  server = "metrics.${var.domain}"
  port   = 443

  influx_db_proto        = "https"
  influx_api_path_prefix = "/influx"
  influx_organization    = "proxmox"
  influx_bucket          = "proxmox"
}

# -----------------------------------------------------
# Ansible
# -----------------------------------------------------

# No hosts, the management VMs are in the gitops root. build.sh writes
# playbooks/inventory/clusters.generated.yml from the outputs (ansible_vars, talosconfigs), so
# mgmt.yml can copy the talosconfigs to them. It was a file written by Terraform: forgotten, not
# deleted, like the talosconfigs (modules/talos-cluster).
removed {
  from = local_file.ansible_inventory

  lifecycle {
    destroy = false
  }
}
