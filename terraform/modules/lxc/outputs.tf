output "ipv4" {
  value = proxmox_virtual_environment_container.this.network_interface[0].ipv4_addresses
}
