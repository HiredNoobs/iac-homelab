terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.94.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://proxmox.hirednoobs.online/api2/json"
  username = var.pm_user
  password = var.pm_password
  insecure = true
}

resource "random_password" "container_password" {
  for_each = var.nodes

  length  = 32
  special = true
  override_special = "!@#$%^&*()-_=+[]:,.?"
}

module "lxc" {
  source = "./modules/lxc"

  providers = {
    proxmox = proxmox
  }

  for_each = var.nodes

  node       = "homelab"
  vmid       = each.value.vmid
  hostname   = each.value.hostname
  tags       = each.value.tags

  ostemplate = var.ostemplate
  ostype     = var.ostype
  root_password = random_password.container_password[each.key].result

  cores   = each.value.cores
  memory  = each.value.memory
  disk    = each.value.disk
  storage = var.storage
  bridge  = var.bridge
  ip      = each.value.ip
  gateway = var.gateway
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    nodes     = var.nodes
    passwords = random_password.container_password
  })

  filename = "${path.module}/../playbooks/inventory.generated.yml"
}

locals {
  nodes_list = [
    for k, v in var.nodes : {
      hostname = v.hostname
      ip       = v.ip
    }
  ]

  nodes_sorted = sort([
    for n in local.nodes_list :
    "${split("/", n.ip)[0]}|${n.hostname}"
  ])

  nodes_sorted_objects = [
    for entry in local.nodes_sorted : {
      ip       = split("|", entry)[0]
      hostname = split("|", entry)[1]
    }
  ]
}

resource "local_file" "hosts_file" {
  content = templatefile("${path.module}/templates/hosts.tpl", {
    nodes = local.nodes_sorted_objects
  })

  filename = "${path.module}/../playbooks/roles/movein/files/hosts.generated"
}
