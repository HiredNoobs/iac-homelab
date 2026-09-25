output "endpoint" {
  value = local.endpoint
}

output "talosconfig_path" {
  value = local_sensitive_file.talosconfig.filename
}
