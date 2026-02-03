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
    disk     = number
    ip       = string
    env      = string
    stack    = string
  }))
}


variable "ostemplate" {
  default = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "ostype" {
  default = "debian"
}

variable "storage" {
  default = "local-lvm"
}

variable "bridge" {
  default = "vmbr0"
}
