variable "vmid" {}
variable "hostname" {}
variable "ostemplate" {}

variable "cores" {}
variable "memory" {}
variable "disk" {}
variable "storage" {}
variable "bridge" {}
variable "ip" {}
variable "nesting" {
  default = true
}

variable "node" {
  description = "Proxmox node name"
}
