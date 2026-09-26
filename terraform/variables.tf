variable "pm_user" {
  type = string
}

variable "pm_password" {
  type      = string
  sensitive = true
}

# An IP, not a name, so the initial build doesn't depend on Pi-hole (which runs in the cluster).
variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.111.2:8006/"
}

# -----------------------------------------------------
# Network
# -----------------------------------------------------

variable "domain" {
  type    = string
  default = "hirednoobs.com"
}

variable "gateway" {
  type    = string
  default = "192.168.111.1"
}

# In order of preference. Changes are applied to running nodes without a reboot.
# The router provides DNS for the lab VLAN and falls back to an upstream resolver,
# so the nodes can still pull images when the in-cluster Pi-hole is down.
variable "nameservers" {
  type    = list(string)
  default = ["192.168.111.1"]
}

variable "bridge" {
  type    = string
  default = "vmbr0"
}

# Only needed if the bridge is VLAN aware (trunk), leave null if it is already untagged in VLAN 111.
variable "vlan_id" {
  type    = number
  default = null
}

# -----------------------------------------------------
# Storage
# -----------------------------------------------------

# Needs the "ISO image" content type, the Talos and Debian disk images are downloaded here.
variable "image_datastore" {
  type    = string
  default = "local"
}

variable "vm_datastore" {
  type    = string
  default = "vmdata"
}

# -----------------------------------------------------
# Talos
# -----------------------------------------------------

# Installed Talos version, bumping this upgrades the nodes in place.
variable "talos_version" {
  type    = string
  default = "v1.14.1"
}

# Machine config contract, keep this at the version the clusters were created with.
# See https://docs.siderolabs.com/talos/latest/configure-your-talos-cluster/system-configuration/reproducible-machine-configuration
variable "talos_contract" {
  type    = string
  default = "v1.14"
}

# Bumping this runs Talos's upgrade-k8s procedure via talos_cluster.
variable "kubernetes_version" {
  type    = string
  default = "v1.37.0"
}

variable "talos_extensions" {
  type    = list(string)
  # iscsi-tools and util-linux-tools are required by Longhorn.
  default = ["qemu-guest-agent", "iscsi-tools", "util-linux-tools"]
}

# Where each cluster's talosconfig is written, as <context>.yaml (used by tools-bin's context-setup).
variable "talosconfig_dir" {
  type    = string
  default = "~/.talos/contexts"
}

# -----------------------------------------------------
# Management
# -----------------------------------------------------

# Only used to create the management VMs, they're patched in place by Ansible.
variable "debian_image_url" {
  type    = string
  default = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
}

# Created on the management VMs by cloud-init, Ansible connects as this user.
variable "admin_user" {
  type    = string
  default = "hirednoobs"
}

# Authorized for admin_user, this is the key Ansible uses.
variable "ssh_public_key_file" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

# Management VMs, the jumpboxes that manage the clusters. Named
# prx-<host>-srv-mgmt-<number>, the Proxmox node is taken from the name.
variable "management_hosts" {
  type = map(object({
    vmid   = number
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))
  default = {}

  validation {
    condition     = alltrue([for name in keys(var.management_hosts) : can(regex("^prx-[0-9]+-srv-mgmt-[0-9]+$", name))])
    error_message = "Management host names must look like prx-<host>-srv-mgmt-<number>, e.g. prx-001-srv-mgmt-001."
  }

  # Same per node allocation as the clusters, management VMs count down from X99.
  validation {
    condition = alltrue([
      for name, host in var.management_hosts :
      !can(regex("^prx-([0-9]+)-", name)) || floor(host.vmid / 100) == tonumber(regex("^prx-([0-9]+)-", name)[0])
    ])
    error_message = "Management VMIDs must be in their Proxmox node's range, e.g. prx-001 hosts use 100-199."
  }

  validation {
    condition     = length(distinct([for host in values(var.management_hosts) : host.vmid])) == length(var.management_hosts)
    error_message = "Management VMIDs must be unique."
  }

  validation {
    condition = length(setintersection(
      [for host in values(var.management_hosts) : host.vmid],
      flatten([for cluster in values(var.clusters) : [for node in values(cluster.nodes) : node.vmid]]),
    )) == 0
    error_message = "Management VMIDs must not be used by any cluster node."
  }
}

# -----------------------------------------------------
# Clusters
# -----------------------------------------------------

# Keyed by context name (e.g. production.core). Node names encode the Proxmox node they
# run on and their role, e.g. prx-001-srv-prod-core-control-001 is a control plane on prx-001
# and prx-002-srv-prod-core-worker-001 is a worker in the worker-001 pool on prx-002.
variable "clusters" {
  type = map(object({
    name = string
    vip  = string
    nodes = map(object({
      vmid   = number
      ip     = string
      cores  = number
      memory = number
      disk   = number
      labels = optional(map(string), {})

      longhorn_disk = optional(number)
    }))
  }))

  validation {
    condition = alltrue(flatten([
      for cluster in values(var.clusters) : [
        for name in keys(cluster.nodes) : can(regex("^prx-[0-9]+-.+-(control|worker)-[0-9]+$", name))
      ]
    ]))
    error_message = "Node names must look like prx-<host>-...-<control|worker>-<number>, e.g. prx-001-srv-prod-core-worker-001."
  }

  validation {
    condition = alltrue([
      for cluster in values(var.clusters) :
      length([for name in keys(cluster.nodes) : name if can(regex("-control-[0-9]+$", name))]) > 0
    ])
    error_message = "Each cluster needs at least one control plane node."
  }

  # VMIDs are allocated per Proxmox node: prx-001 = 100-199, prx-002 = 200-299, ...
  validation {
    condition = alltrue(flatten([
      for cluster in values(var.clusters) : [
        for name, node in cluster.nodes :
        !can(regex("^prx-([0-9]+)-", name)) || floor(node.vmid / 100) == tonumber(regex("^prx-([0-9]+)-", name)[0])
      ]
    ]))
    error_message = "VMIDs must be in their Proxmox node's range, e.g. prx-001 nodes use 100-199."
  }

  validation {
    condition = length(flatten([
      for cluster in values(var.clusters) : [for node in values(cluster.nodes) : node.vmid]
      ])) == length(distinct(flatten([
        for cluster in values(var.clusters) : [for node in values(cluster.nodes) : node.vmid]
    ])))
    error_message = "VMIDs must be unique across all clusters."
  }
}
