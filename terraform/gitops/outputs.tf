output "servers" {
  value = { for name, server in module.server : name => server.ip }
}
