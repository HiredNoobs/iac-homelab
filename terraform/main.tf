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

  cores   = each.value.cores
  memory  = each.value.memory
  disk    = each.value.disk
  storage = var.storage
  bridge  = var.bridge
  ip      = each.value.ip
}
