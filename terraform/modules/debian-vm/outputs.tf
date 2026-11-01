output "ip" {
  value = split("/", var.ip)[0]
}
