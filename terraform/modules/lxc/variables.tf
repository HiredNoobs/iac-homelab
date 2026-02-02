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
  type    = bool
  default = true
}
