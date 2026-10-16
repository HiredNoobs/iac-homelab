terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

locals {
  repositories = {
    "enterprise"            = false
    "ceph-squid-enterprise" = false
    "no-subscription"       = true
  }
}

resource "proxmox_apt_standard_repository" "this" {
  for_each = local.repositories

  handle = each.key
  node   = var.node_name
}

resource "proxmox_apt_repository" "this" {
  for_each = local.repositories

  node      = var.node_name
  file_path = proxmox_apt_standard_repository.this[each.key].file_path
  index     = proxmox_apt_standard_repository.this[each.key].index
  enabled   = each.value
}
