# Note: env/stack are only used for generating the inventory for Ansible.
nodes = {
  # -----------------------------------------------------
  # Dev (900 - 999)
  # -----------------------------------------------------
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

  # -----------------------------------------------------
  # Prod Core (500 - 599)
  # -----------------------------------------------------

  rsyslog001 = {
    vmid     = 500
    hostname = "prod-rsyslog001"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 512
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
    memory   = 512
    disk     = 4
    ip       = "192.168.50.202/24"

    env      = "production"
    stack    = "rsyslog"
  }

  kafka001 = {
    vmid     = 502
    hostname = "prod-kafka001"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 1024
    disk     = 10
    ip       = "192.168.50.206/24"

    env      = "production"
    stack    = "kafka"
  }

  kafka002 = {
    vmid     = 503
    hostname = "prod-kafka002"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 1024
    disk     = 10
    ip       = "192.168.50.207/24"

    env      = "production"
    stack    = "kafka"
  }

  kafka003 = {
    vmid     = 504
    hostname = "prod-kafka003"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 1024
    disk     = 10
    ip       = "192.168.50.208/24"

    env      = "production"
    stack    = "kafka"
  }

  redis001 = {
    vmid     = 505
    hostname = "prod-redis001"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 1024
    disk     = 10
    ip       = "192.168.50.209/24"

    env      = "production"
    stack    = "redis"
  }

  # Leaving VMID / IP space for a Redis cluster...

  rabbitmq001 = {
    vmid     = 508
    hostname = "prod-contentbot001"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 1024
    disk     = 10
    ip       = "192.168.50.212/24"

    env      = "production"
    stack    = "rabbitmq"
  }

  # Leaving VMID / IP space for a RabbitMQ cluster...

  contentbot001 = {
    vmid     = 511
    hostname = "prod-contentbot001"
    tags     = ["docker", "production.core"]

    cores    = 1
    memory   = 1024
    disk     = 10
    ip       = "192.168.50.215/24"

    env      = "production"
    stack    = "contentbot"
  }

  # -----------------------------------------------------
  # Prod Services (600 - 699)
  # -----------------------------------------------------

  vault001 = {
    vmid     = 600
    hostname = "prod-vault001"
    tags     = ["docker", "production.services"]

    cores    = 1
    memory   = 512
    disk     = 10
    ip       = "192.168.50.204/24"

    env      = "production"
    stack    = "vault"
  }

  vault002 = {
    vmid     = 601
    hostname = "prod-vault002"
    tags     = ["docker", "production.services"]

    cores    = 1
    memory   = 512
    disk     = 10
    ip       = "192.168.50.205/24"

    env      = "production"
    stack    = "vault"
  }
}
