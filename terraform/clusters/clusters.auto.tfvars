# Clusters keyed by the context name used by tools-bin (`context-setup`).
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
#   .11  - .99   Nodes, .X1 - .X9 on prx-00X (prx-002 = .21 - .29), control plane first
#   .100 - .149  LoadBalancer IPs, announced by kube-vip (iac-k8s)
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
        memory = 4096
        disk   = 50
      }

      prx-001-srv-prod-core-worker-001 = {
        vmid = 110
        ip   = "192.168.111.12/24"

        cores  = 4
        memory = 12288
        disk   = 40

        longhorn_disk = 100
      }

      prx-001-srv-prod-core-worker-002 = {
        vmid = 111
        ip   = "192.168.111.13/24"

        cores  = 4
        memory = 12288
        disk   = 40

        longhorn_disk = 50
      }

      prx-002-srv-prod-core-control-001 = {
        vmid = 200
        ip   = "192.168.111.21/24"

        cores  = 2
        memory = 4096
        disk   = 50
      }

      prx-002-srv-prod-core-worker-001 = {
        vmid = 210
        ip   = "192.168.111.22/24"

        cores  = 4
        memory = 12288
        disk   = 40

        longhorn_disk = 50
      }

      prx-002-srv-prod-core-worker-002 = {
        vmid = 211
        ip   = "192.168.111.23/24"

        cores  = 4
        memory = 12288
        disk   = 40

        longhorn_disk = 50
      }

      prx-003-srv-prod-core-control-001 = {
        vmid = 300
        ip   = "192.168.111.31/24"

        cores  = 2
        memory = 4096
        disk   = 50
      }

      prx-003-srv-prod-core-worker-001 = {
        vmid = 310
        ip   = "192.168.111.32/24"

        cores  = 4
        memory = 12288
        disk   = 40

        longhorn_disk = 50
      }

      prx-003-srv-prod-core-worker-002 = {
        vmid = 311
        ip   = "192.168.111.33/24"

        cores  = 4
        memory = 12288
        disk   = 40

        longhorn_disk = 50
      }
    }
  }
}
