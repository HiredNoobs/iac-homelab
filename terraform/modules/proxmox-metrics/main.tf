terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

# The hosts' own and their guests' and storages' stats, pushed by pvestatd every 10 seconds as
# InfluxDB lines to the Kubernetes cluster's vmagent (iac-k8s apps/base/monitoring/vmagent). One
# setting for the whole Proxmox cluster (/etc/pve/status.cfg). vmagent takes them without a token;
# org and bucket are only there because the v2 API's URL needs them. The /influx prefix is where
# vmagent has both the writes and the health check Proxmox makes when the server is added or
# changed (/health without it is vmagent's own). While the cluster is down the stats are lost.
resource "proxmox_metrics_server" "this" {
  name    = "vmagent"
  type    = "influxdb"
  server  = "metrics.${var.domain}"
  port    = 443
  disable = !var.enabled

  influx_db_proto        = "https"
  influx_api_path_prefix = "/influx"
  influx_organization    = "proxmox"
  influx_bucket          = "proxmox"
}
