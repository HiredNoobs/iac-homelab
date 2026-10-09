# The clusters ESO runs in, see variables.tf. host is the cluster's API VIP from the clusters root.
clusters = {
  production-core = {
    host        = "https://192.168.111.10:6443"
    environment = "production"
  }
}
