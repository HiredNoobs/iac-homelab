# Same as the clusters root for now (root@pam), a scoped API token can replace it later.
variable "pm_user" {
  type = string
}

variable "pm_password" {
  type      = string
  sensitive = true
}

# An IP, not a name, so the build doesn't depend on any DNS server.
variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.111.9:8006/"
}

variable "proxmox_node" {
  type    = string
  default = "prx-999"
}

# -----------------------------------------------------
# Network
# -----------------------------------------------------

variable "domain" {
  type    = string
  default = "hirednoobs.com"
}

variable "gateway" {
  type    = string
  default = "192.168.111.1"
}

# The router, never the in-cluster Pi-hole, prx-999 has to work while the cluster is down.
variable "nameservers" {
  type    = list(string)
  default = ["192.168.111.1"]
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

# Only needed if the bridge is VLAN aware (trunk), leave null if it is already untagged in VLAN 111.
variable "vlan_id" {
  type    = number
  default = null
}

# -----------------------------------------------------
# Storage
# -----------------------------------------------------

# Needs the "ISO image" content type, the Debian disk image is downloaded here.
variable "image_datastore" {
  type    = string
  default = "local"
}

variable "vm_datastore" {
  type    = string
  default = "local-lvm"
}

# -----------------------------------------------------
# Servers
# -----------------------------------------------------

# Only used to create the VMs, they're patched in place by Ansible.
variable "debian_image_url" {
  type    = string
  default = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

# Created on the VMs by cloud-init, Ansible connects as this user.
variable "admin_user" {
  type    = string
  default = "hirednoobs"
}

# Authorized for admin_user, this is the key Ansible uses.
variable "ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

# Named prx-999-srv-<role>-<number>, the role is the VM's Ansible group (e.g. vault).
variable "servers" {
  type = map(object({
    vmid   = number
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))

  validation {
    condition     = alltrue([for name in keys(var.servers) : can(regex("^prx-999-srv-[a-z]+-[0-9]+$", name))])
    error_message = "Server names must look like prx-999-srv-<role>-<number>, e.g. prx-999-srv-vault-001."
  }

  validation {
    condition     = length(distinct([for server in values(var.servers) : server.vmid])) == length(var.servers)
    error_message = "Server VMIDs must be unique."
  }
}
