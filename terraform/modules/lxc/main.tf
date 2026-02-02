terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_lxc" "this" {
  node_name = var.node
  vm_id     = var.vmid

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = var.ip
      }
    }
  }

  operating_system {
    template_file_id = var.ostemplate
  }

  cpu {
    cores = var.cores
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    size         = var.disk
  }

  network {
    name   = "eth0"
    bridge = var.bridge
  }

  features {
    nesting = var.nesting
  }

  start_on_boot = true
  started       = true
}
