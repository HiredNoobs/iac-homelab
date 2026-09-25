variable "context" {
  description = "Context name used by tools-bin, e.g. production.core"
  type        = string
}

variable "name" {
  description = "Talos/Kubernetes cluster name"
  type        = string
}

variable "vip" {
  description = "Layer 2 VIP shared by the control plane nodes, used as the Kubernetes API endpoint"
  type        = string
}

variable "nodes" {
  type = map(object({
    vmid   = number
    ip     = string
    cores  = number
    memory = number
    disk   = number
    labels = map(string)
  }))
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

variable "image_file_ids" {
  description = "Talos disk image file ID per Proxmox node"
  type        = map(string)
}

variable "installer_image" {
  type = string
}

variable "talos_contract" {
  type = string
}

variable "kubernetes_version" {
  type = string
}

variable "talosconfig_path" {
  type = string
}
