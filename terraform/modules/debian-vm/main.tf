terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

resource "proxmox_virtual_environment_vm" "this" {
  name        = var.name
  node_name   = var.node_name
  vm_id       = var.vmid
  tags        = var.tags
  description = var.description

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"

  on_boot         = true
  stop_on_destroy = true

  # qemu-guest-agent isn't in the cloud image, Ansible installs it. The IP is static
  # so there's no need to wait on the agent for it.
  agent {
    enabled = true
    trim    = true

    wait_for_ip {
      disabled = true
    }
  }

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.vm_datastore
    file_id      = var.image_file_id
    interface    = "scsi0"
    file_format  = "raw"
    size         = var.disk
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge  = var.bridge
    model   = "virtio"
    vlan_id = var.vlan_id
  }

  # Debian cloud images log the console to ttyS0.
  serial_device {}

  operating_system {
    type = "l26"
  }

  # The hostname is taken from the VM name. The user gets passwordless sudo from
  # the image's cloud-init defaults, it's only reachable with the SSH keys.
  initialization {
    datastore_id = var.vm_datastore

    ip_config {
      ipv4 {
        address = var.ip
        gateway = var.gateway
      }
    }

    dns {
      domain  = var.domain
      servers = var.nameservers
    }

    user_account {
      username = var.admin_user
      keys     = var.ssh_public_keys
    }
  }

  lifecycle {
    # The image is only used for the first boot, Ansible patches the VM in place.
    ignore_changes = [disk[0].file_id]
  }
}
