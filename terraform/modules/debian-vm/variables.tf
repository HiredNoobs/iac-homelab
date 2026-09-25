variable "name" {
  description = "VM name, also used as the hostname"
  type        = string
}

variable "node_name" {
  description = "Proxmox node the VM runs on"
  type        = string
}

variable "vmid" {
  type = number
}

variable "tags" {
  type    = list(string)
  default = []
}

variable "description" {
  type    = string
  default = null
}

variable "ip" {
  description = "Static IP in CIDR notation, e.g. 192.168.111.254/24"
  type        = string
}

variable "cores" {
  type = number
}

variable "memory" {
  type = number
}

variable "disk" {
  type = number
}

variable "domain" {
  type = string
}

variable "gateway" {
  type = string
}

variable "nameservers" {
  type = list(string)
}

variable "bridge" {
  type = string
}

variable "vlan_id" {
  type    = number
  default = null
}

variable "vm_datastore" {
  type = string
}

variable "image_file_id" {
  description = "Debian cloud image file ID on the VM's Proxmox node"
  type        = string
}

variable "admin_user" {
  description = "User created by cloud-init, Ansible connects as this user"
  type        = string
}

variable "ssh_public_keys" {
  type = list(string)
}
