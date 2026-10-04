output "installer_image" {
  value = data.talos_image_factory_urls.this.urls.installer
}

output "clusters" {
  value = {
    for context, cluster in module.cluster : context => {
      endpoint    = cluster.endpoint
      talosconfig = cluster.talosconfig_path
    }
  }
}

output "management_hosts" {
  value = { for name, host in module.management : name => host.ip }
}
