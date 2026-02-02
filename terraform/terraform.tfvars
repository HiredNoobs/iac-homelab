nodes = {
  atlas = {
    vmid     = 999
    hostname = "atlas"
    cores    = 2
    memory   = 4096
    disk     = 20
    ip       = "192.168.50.201/24"

    env      = "development"
    stack    = "misc"
  }

  rsyslog001 = {
    vmid     = 500
    hostname = "prod-rsyslog001"
    cores    = 2
    memory   = 4096
    disk     = 10
    ip       = "192.168.50.202/24"

    env      = "production"
    stack    = "rsyslog"
  }

  rsyslog002 = {
    vmid     = 501
    hostname = "prod-rsyslog002"
    cores    = 2
    memory   = 4096
    disk     = 10
    ip       = "192.168.50.203/24"

    env      = "production"
    stack    = "rsyslog"
  }
}
