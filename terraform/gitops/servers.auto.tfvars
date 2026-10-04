# The prx-999 VMs, configured by the Ansible playbooks in playbooks/ (see build.sh gitops).
#
# Names are prx-999-srv-<role>-<number>, the role is the VM's Ansible group.
#
# prx-999 isn't in the prx-00x cluster, so the per node VMID rule doesn't apply. mgmt VMs
# count down from 999, everything else counts up from 900. IPs in 192.168.111.0/24:
#   .200 - .249  Servers, counting up
#   .250 - .254  Management VMs, counting down from .254
servers = {
  # The jumpbox: tools-bin, talosctl and kubectl for every cluster (mgmt.yml), and later the
  # infra runner, the only place with the Proxmox and Talos credentials.
  prx-999-srv-mgmt-001 = {
    vmid = 999
    ip   = "192.168.111.254/24"

    cores  = 2
    memory = 4096
    disk   = 30
  }

  prx-999-srv-git-001 = {
    vmid = 900
    ip   = "192.168.111.200/24"

    cores  = 2
    memory = 3072
    disk   = 50
  }

  prx-999-srv-runner-001 = {
    vmid = 901
    ip   = "192.168.111.201/24"

    cores  = 4
    memory = 4096
    disk   = 60
  }

  prx-999-srv-vault-001 = {
    vmid = 902
    ip   = "192.168.111.202/24"

    cores  = 1
    memory = 1536
    disk   = 10
  }
}
