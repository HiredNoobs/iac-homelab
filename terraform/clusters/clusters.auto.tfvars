# Clusters keyed by the context name used by tools-bin (`deployment`/`context-setup`).
#
# Node names are prx-<host>-...-<control|worker>-<number>. The Proxmox node, role
# and labels are taken from the name:
#   prx-002-srv-prod-core-worker-001 -> worker on prx-002
#     topology.kubernetes.io/zone = prx-002
#     hirednoobs.com/pool         = worker-001
#
# VMIDs are allocated per Proxmox node (prx-001 = 100-199, prx-002 = 200-299, ...):
#   X00 - X09  Control planes
#   X10 - X89  Workers
#   X90 - X99  Unused, previously the management VMs (now on prx-999, terraform/gitops)
#
# IPs in 192.168.111.0/24:
#   .10          Kubernetes API VIP
#   .11  - .99   Nodes
#   .100 - .149  LoadBalancer IPs, announced by kube-vip (stack-kube-vip)
#   .200 - .254  prx-999 VMs (terraform/gitops), the management VMs count down from .254
#
# Extra labels can be added per node with `labels`.
#
# `longhorn_disk` adds a second disk mounted at /var/mnt/longhorn and labels the
# node node.longhorn.io/create-default-disk=true, only these nodes get a Longhorn disk.
clusters = {
  # -----------------------------------------------------
  # Prod Core
  # -----------------------------------------------------
  "production.core" = {
    name = "production-core"
    vip  = "192.168.111.10"

    nodes = {
      prx-001-srv-prod-core-control-001 = {
        vmid = 100
        ip   = "192.168.111.11/24"

        cores  = 2
        memory = 2048
        disk   = 50
      }

      prx-001-srv-prod-core-worker-001 = {
        vmid = 110
        ip   = "192.168.111.12/24"

        cores  = 4
        memory = 4096
        disk   = 20

        longhorn_disk = 50

        labels = {
          pihole_core_pihole = ""
          nginx_core_nginx   = ""
        }
      }

      prx-001-srv-prod-core-worker-002 = {
        vmid = 111
        ip   = "192.168.111.13/24"

        cores  = 4
        memory = 4096
        disk   = 20

        longhorn_disk = 50

        labels = {
          redis_core_redis        = ""
          rabbitmq_core_broker    = ""
          contentbot_core_chatbot = ""
          contentbot_core_worker  = ""
          homepage_core_homepage  = ""
        }
      }

      prx-001-srv-prod-core-worker-003 = {
        vmid = 112
        ip   = "192.168.111.14/24"

        cores  = 4
        memory = 4096
        disk   = 20

        longhorn_disk = 50

        labels = {
          vault_core_vault             = ""
          vaultwarden_core_vaultwarden = ""
          lldap_core_lldap             = ""
          authelia_core_authelia       = ""
        }
      }

      prx-001-srv-prod-core-worker-004 = {
        vmid = 113
        ip   = "192.168.111.15/24"

        cores  = 4
        memory = 4096
        disk   = 20

        longhorn_disk = 50

        labels = {
          grafana_core_grafana         = ""
          grafana_core_victorialogs    = ""
          grafana_core_victoriametrics = ""
          grafana_core_vmagent         = ""
          grafana_core_vmalert         = ""
          grafana_core_alertmanager    = ""
          rsyslog_core_rsyslog         = ""
        }
      }
    }
  }
}
