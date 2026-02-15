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
    tags     = list(string)
    cores    = number
    memory   = number
    disk     = number
    ip       = string
    env      = string
    stack    = string
  }))
}


variable "ostemplate" {
  type = string
  default = "local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
}

variable "ostype" {
  type = string
  default = "debian"
}

variable "storage" {
  type = string
  default = "local-lvm"
}

variable "bridge" {
  type = string
  default = "vmbr0"
}

variable "gateway" {
  type = string
  default = "192.168.50.11"
}
