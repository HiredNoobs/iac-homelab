terraform {
  # Exact, upgrades are deliberate. Write-only arguments (kubeconfig_wo) need 1.11+.
  required_version = "1.16.6"

  # In Postgres on the git VM (PG_CONN_STR, set by build.sh). Without it, from a copy on the NAS:
  # README, Terraform state.
  backend "pg" {
    schema_name = "clusters"
  }

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.116.1"
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
