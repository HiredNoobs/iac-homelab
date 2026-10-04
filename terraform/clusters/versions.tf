terraform {
  # Exact, upgrades are deliberate. Write-only arguments (kubeconfig_wo) need 1.11+.
  required_version = "1.15.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.114.0"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.12.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  username = var.pm_user
  password = var.pm_password
  insecure = true
}

provider "talos" {}
