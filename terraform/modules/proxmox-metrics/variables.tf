variable "domain" {
  description = "Domain vmagent is under, as metrics.<domain>"
  type        = string
}

variable "enabled" {
  description = "Whether Proxmox sends the stats, false while vmagent isn't up"
  type        = bool
}
