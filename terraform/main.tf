terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.94.0"
    }
  }
}

provider "proxmox" {
  pm_api_url      = "https://proxmox.hirednoobs.online/api2/json"
  pm_user         = var.pm_user
  pm_password     = var.pm_password
  pm_tls_insecure = true
}


module "lxc" {
  source = "./modules/lxc"

  for_each = var.nodes

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
