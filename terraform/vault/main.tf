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

# -----------------------------------------------------
# CI (Forgejo Actions)
# -----------------------------------------------------

# Jobs log in with the ID token Forgejo signs for them (enable-openid-connect), whose claims say
# which repo, workflow file, branch, event and user the run is for. Forgejo gives repo secrets to
# a workflow on any pushed branch, so CI credentials live here instead, released only to runs
# the claims vouch for. Vault checks the tokens against Forgejo's keys
# (<issuer>/.well-known/openid-configuration).
resource "vault_jwt_auth_backend" "forgejo" {
  path               = "forgejo"
  type               = "jwt"
  description        = "Forgejo Actions ID tokens"
  oidc_discovery_url = "${var.forgejo_url}/api/actions"
  bound_issuer       = "${var.forgejo_url}/api/actions"
}

locals {
  iac_homelab = "${var.forgejo_owner}/iac-homelab"

  # The clusters workflow as master has it: pushes to master and pull_request_target runs both
  # read the workflow from there, a branch's own copy is never it.
  clusters_workflow = {
    repository   = local.iac_homelab
    workflow_ref = "${local.iac_homelab}/.forgejo/workflows/clusters.yml@refs/heads/master"
    ref          = "refs/heads/master"
    actor        = var.forgejo_owner
  }
}

# labv2/ci/clusters: PM_PASSWORD (the clusters' Proxmox root@pam) and PG_PASSWORD (the
# terraform_ci role's, the same as iac-homelab's secrets/postgres-password-ci). Outside
# labv2/<environment>/, so External Secrets Operator can't read it.
resource "vault_policy" "ci_clusters" {
  name   = "ci-clusters"
  policy = <<-EOT
    path "${vault_mount.labv2.path}/data/ci/clusters" {
      capabilities = ["read"]
    }
  EOT
}

# Applying: a merge into master (only the owner can merge, iac-homelab's branch protection), so
# master's own code.
resource "vault_jwt_auth_backend_role" "clusters_apply" {
  backend           = vault_jwt_auth_backend.forgejo.path
  role_name         = "clusters-apply"
  role_type         = "jwt"
  user_claim        = "actor"
  bound_audiences   = [var.vault_address]
  bound_claims_type = "string"
  bound_claims      = merge(local.clusters_workflow, { event_name = "push" })
  token_policies    = [vault_policy.ci_clusters.name]
  token_ttl         = 600
  token_max_ttl     = 600
}

# Planning a pull request: master's workflow (pull_request_target) started by the owner, by
# opening or updating their own pull request or labelling someone else's (Renovate's) after
# reading it. A commit pushed by anyone else starts a run Vault refuses.
resource "vault_jwt_auth_backend_role" "clusters_plan" {
  backend           = vault_jwt_auth_backend.forgejo.path
  role_name         = "clusters-plan"
  role_type         = "jwt"
  user_claim        = "actor"
  bound_audiences   = [var.vault_address]
  bound_claims_type = "string"
  bound_claims      = merge(local.clusters_workflow, { event_name = "pull_request_target" })
  token_policies    = [vault_policy.ci_clusters.name]
  token_ttl         = 600
  token_max_ttl     = 600
}

# -----------------------------------------------------
# Audit
# -----------------------------------------------------

# Every request and response, with secrets and tokens HMAC'd. Two devices because Vault refuses
# every request when no audit device can write: a full disk shouldn't stop it while the journal
# still works, and the other way round.
#
# stdout lands in the journal (vault.service), which systemd-journal-upload sends to
# VictoriaLogs for the security detections (iac-k8s rules/journald.yml). The file stays on the
# VM, rotated by the vault role's logrotate (which reloads Vault so it reopens it); the
# directory has to exist first (vault.yml), or Vault refuses to enable the device.
resource "vault_audit" "stdout" {
  type = "file"
  path = "stdout"

  options = {
    file_path            = "stdout"
    elide_list_responses = "true"
  }
}

resource "vault_audit" "file" {
  type = "file"
  path = "file"

  options = {
    file_path            = "/var/log/vault/audit.log"
    mode                 = "0600"
    elide_list_responses = "true"
  }
}
