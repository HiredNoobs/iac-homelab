terraform {
  # Exact, upgrades are deliberate. Kept in step with the clusters root.
  required_version = "1.15.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.114.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.1"
    }
  }
}

# prx-999 is a standalone Proxmox node, not part of the prx-00x cluster, so it has its own API.
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.pm_user
  password = var.pm_password
  insecure = true
}
