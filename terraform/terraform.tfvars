nodes = {
  atlas = {
    vmid     = 999
    hostname = "atlas"
    cores    = 2
    memory   = 4096
    disk     = 20
    ip       = "dhcp"
  }

  rsyslog001 = {
    vmid     = 500
    hostname = "prod-rsyslog001"
    cores    = 2
    memory   = 4096
    disk     = 10
    ip       = "dhcp"
  }

  rsyslog002 = {
    vmid     = 501
    hostname = "prod-rsyslog002"
    cores    = 2
    memory   = 4096
    disk     = 10
    ip       = "dhcp"
  }
}
