# Management VMs, the Debian jumpboxes used to manage the clusters.
# They're configured by the Ansible playbooks in playbooks/ (see build.sh).
#
# Names are prx-<host>-srv-mgmt-<number>, the Proxmox node is taken from the name.
#
# VMIDs count down from the top of their Proxmox node's range (prx-001 = 199, 198, ...,
# prx-002 = 299, ...). IPs count down from the top of the subnet:
#   prx-001-srv-mgmt-001 = 199 / 192.168.111.254
#   prx-002-srv-mgmt-002 = 299 / 192.168.111.253
#   ...
management_hosts = {
  prx-001-srv-mgmt-001 = {
    vmid = 199
    ip   = "192.168.111.254/24"

    cores  = 2
    memory = 4096
    disk   = 30
  }
}
