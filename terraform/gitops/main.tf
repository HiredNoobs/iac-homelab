locals {
  # prx-999-srv-vault-001 -> vault
  roles = { for name in keys(var.servers) : name => regex("^prx-999-srv-([a-z]+)-", name)[0] }
}

# -----------------------------------------------------
# Servers
# -----------------------------------------------------

# Only used to create VMs, they're patched in place by Ansible.
resource "proxmox_download_file" "debian" {
  node_name    = var.proxmox_node
  content_type = "iso"
  datastore_id = var.image_datastore
  file_name    = "debian-13-genericcloud-amd64.img"
  url          = var.debian_image_url
  overwrite    = false
}

module "server" {
  source   = "../modules/debian-vm"
  for_each = var.servers

  name        = each.key
  node_name   = var.proxmox_node
  vmid        = each.value.vmid
  tags        = ["debian", "gitops", local.roles[each.key]]
  description = "GitOps server (${local.roles[each.key]}), managed by iac-homelab."

  ip     = each.value.ip
  cores  = each.value.cores
  memory = each.value.memory
  disk   = each.value.disk

  domain      = var.domain
  gateway     = var.gateway
  nameservers = var.nameservers
  bridge      = var.bridge
  vlan_id     = var.vlan_id

  vm_datastore  = var.vm_datastore
  image_file_id = proxmox_download_file.debian.id

  admin_user      = var.admin_user
  ssh_public_keys = [trimspace(file(pathexpand(var.ssh_public_key_file)))]
}

# -----------------------------------------------------
# Ansible
# -----------------------------------------------------

# Merged with the clusters root's inventory by Ansible, see playbooks/ansible.cfg.
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../../playbooks/inventory/gitops.generated.yml"
  file_permission = "0644"

  content = yamlencode({
    all = {
      vars = {
        domain      = var.domain
        nameservers = var.nameservers
        admin_user  = var.admin_user
      }
      children = {
        # Everything this root creates, build.sh limits the playbooks to it.
        gitops = {
          children = {
            for role in distinct(values(local.roles)) : role => {
              hosts = {
                for name, host in module.server : name => {
                  ansible_host = host.ip
                  ansible_user = var.admin_user
                } if local.roles[name] == role
              }
            }
          }
        }
      }
    }
  })
}
