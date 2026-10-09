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

  talosconfig_path = pathexpand("${var.talosconfig_dir}/${each.key}.yaml")
}

# -----------------------------------------------------
# Ansible
# -----------------------------------------------------

# No hosts, the management VMs are in the gitops root. Ansible merges every file in
# playbooks/inventory/, so mgmt.yml copies these talosconfigs to them (build.sh clusters runs it
# after an apply).
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../../playbooks/inventory/clusters.generated.yml"
  file_permission = "0644"

  content = yamlencode({
    all = {
      vars = {
        domain       = var.domain
        nameservers  = var.nameservers
        talosconfigs = { for context, cluster in module.cluster : context => cluster.talosconfig_path }
      }
    }
  })
}
