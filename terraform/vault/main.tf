# Vault's config. The secrets themselves aren't managed here, they're written with tools-bin
# (deployment secret push) or the UI. Users (userpass) are added by hand, see the README.

# -----------------------------------------------------
# Secret engines
# -----------------------------------------------------

# Replacing a mount deletes every secret in it, a change to its path or type has to be done by
# hand.
resource "vault_mount" "lab" {
  path    = "lab"
  type    = "kv"
  options = { version = "1" }

  lifecycle {
    prevent_destroy = true
  }
}

# Everything new goes here, labv2/<environment>/<app>.
resource "vault_mount" "labv2" {
  path    = "labv2"
  type    = "kv"
  options = { version = "2" }

  lifecycle {
    prevent_destroy = true
  }
}

# -----------------------------------------------------
# People
# -----------------------------------------------------

resource "vault_auth_backend" "userpass" {
  type = "userpass"
  path = "userpass"
}

# Full access to the KV engines, for the userpass users.
resource "vault_policy" "lab" {
  name   = "lab-policy"
  policy = file("${path.module}/policies/lab-policy.hcl")
}

resource "vault_policy" "labv2" {
  name   = "labv2-policy"
  policy = file("${path.module}/policies/labv2-policy.hcl")
}

# -----------------------------------------------------
# Kubernetes (External Secrets Operator)
# -----------------------------------------------------

resource "vault_auth_backend" "kubernetes" {
  for_each = var.clusters

  type = "kubernetes"
  path = "kubernetes/${each.key}"
}

# No reviewer token: Vault reviews the token ESO logs in with using that same token, ESO's
# service account can (system:auth-delegator, systemAuthDelegator in its HelmRelease).
resource "vault_kubernetes_auth_backend_config" "kubernetes" {
  for_each = var.clusters

  backend              = vault_auth_backend.kubernetes[each.key].path
  kubernetes_host      = each.value.host
  kubernetes_ca_cert   = file("${path.module}/clusters/${each.key}-ca.crt")
  disable_local_ca_jwt = true
}

# Read only, and only the cluster's environment.
resource "vault_policy" "external_secrets" {
  for_each = var.clusters

  name   = "external-secrets-${each.key}"
  policy = <<-EOT
    path "${vault_mount.labv2.path}/data/${each.value.environment}/*" {
      capabilities = ["read"]
    }
  EOT
}

# ESO's controller service account, the ClusterSecretStore in iac-k8s logs in as it.
resource "vault_kubernetes_auth_backend_role" "external_secrets" {
  for_each = var.clusters

  backend                          = vault_auth_backend.kubernetes[each.key].path
  role_name                        = "external-secrets"
  bound_service_account_names      = ["external-secrets"]
  bound_service_account_namespaces = ["external-secrets"]
  token_policies                   = [vault_policy.external_secrets[each.key].name]
  token_ttl                        = 3600
  token_max_ttl                    = 3600
}
