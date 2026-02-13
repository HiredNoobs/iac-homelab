# Note: env/stack are only used for generating the inventory for Ansible.
nodes = {
  atlas = {
    vmid     = 999
    hostname = "atlas"
    tags     = ["docker", "development.core"]

    cores    = 2
    memory   = 4096
    disk     = 20
    ip       = "192.168.50.254/24"

    env      = "development"
    stack    = "misc"
  }

  rsyslog001 = {
    vmid     = 500
    hostname = "prod-rsyslog001"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 1024
    disk     = 4
    ip       = "192.168.50.201/24"

    env      = "production"
    stack    = "rsyslog"
  }

  rsyslog002 = {
    vmid     = 501
    hostname = "prod-rsyslog002"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 1024
    disk     = 4
    ip       = "192.168.50.202/24"

    env      = "production"
    stack    = "rsyslog"
  }

  vault001 = {
    vmid     = 502
    hostname = "prod-vault001"
    tags     = ["docker", "production.services"]

    cores    = 1
    memory   = 1024
    disk     = 4
    ip       = "192.168.50.204/24"

    env      = "production"
    stack    = "vault"
  }

  vault002 = {
    vmid     = 503
    hostname = "prod-vault002"
    tags     = ["docker", "production.services"]

    cores    = 1
    memory   = 1024
    disk     = 4
    ip       = "192.168.50.205/24"

    env      = "production"
    stack    = "vault"
  }
}
