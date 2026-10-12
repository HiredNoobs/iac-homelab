variable "vault_address" {
  type    = string
  default = "https://vault.hirednoobs.com"
}

# Forgejo, whose Actions jobs log in with their ID tokens (OIDC, auth/forgejo).
variable "forgejo_url" {
  type    = string
  default = "https://git.hirednoobs.com"
}

# The owner of the IaC repos, exactly as Forgejo writes it in the tokens' repository and actor
# claims (the case matters). Only this user's runs get CI credentials.
variable "forgejo_owner" {
  type    = string
  default = "HiredNoobs"
}

# The Kubernetes clusters whose External Secrets Operator reads from Vault, keyed by the Flux
# cluster name (iac-k8s's clusters/<name>, Vault's kubernetes/<name> auth mount). Each needs its
# API server's CA in clusters/<name>-ca.crt, see the README.
variable "clusters" {
  type = map(object({
    # The API server, an IP so it doesn't depend on DNS.
    host = string
    # ESO reads labv2/<environment>/*, e.g. labv2/production/<app>.
    environment = string
  }))
}
