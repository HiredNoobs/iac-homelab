# Each cluster's talosconfig, by context. build.sh writes them to ~/.talos/contexts/<context>.yaml
# (used by tools-bin's context-setup), mgmt.yml copies them to the management VMs.
output "talosconfigs" {
  value     = { for context, cluster in module.cluster : context => cluster.talosconfig }
  sensitive = true
}

# The rest of the generated Ansible inventory (build.sh).
output "ansible_vars" {
  value = {
    domain      = var.domain
    nameservers = var.nameservers
  }
}
