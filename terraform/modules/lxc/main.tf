resource "proxmox_lxc" "this" {
  vmid       = var.vmid
  hostname   = var.hostname
  ostemplate = var.ostemplate

  cores  = var.cores
  memory = var.memory

  rootfs {
    storage = var.storage
    size    = var.disk
  }

  network {
    name   = "eth0"
    bridge = var.bridge
    ip     = var.ip
  }

  start  = true
  onboot = true

  features {
    nesting = var.nesting
  }
}
