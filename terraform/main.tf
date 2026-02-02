terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.94.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://proxmox.hirednoobs.online/api2/json"
  username = var.pm_user
  password = var.pm_password
  insecure = true
}

resource "random_password" "container_password" {
  for_each = var.nodes

  length  = 20
  special = true
}

module "lxc" {
  source = "./modules/lxc"

  providers = {
    proxmox = proxmox
  }

  for_each = var.nodes

  node       = "homelab"
  vmid       = each.value.vmid
  hostname   = each.value.hostname
  ostemplate = var.ostemplate
  root_password = random_password.container_password[each.key].result

  cores   = each.value.cores
  memory  = each.value.memory
  disk    = each.value.disk
  storage = var.storage
  bridge  = var.bridge
  ip      = each.value.ip
}
