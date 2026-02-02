variable "pm_user" {
  type = string
}

variable "pm_password" {
  type      = string
  sensitive = true
}


variable "nodes" {
  type = map(object({
    vmid     = number
    hostname = string
    cores    = number
    memory   = number
    disk     = string
    ip       = string
  }))
}

variable "ostemplate" {
  default = "local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"
}

variable "storage" {
  default = "local-lvm"
}

variable "bridge" {
  default = "vmbr0"
}
