#!/usr/bin/env bash
#
# The clusters workflow's Terraform (.forgejo/workflows/clusters.yml), in a job on the runner VM:
#
#   clusters.sh plan <checkout>    plan the clusters root in <checkout> (a pull request's head)
#   clusters.sh apply <checkout>   plan, then apply exactly that plan (master)
#
# The workflow always runs master's copy of this script, checked out apart from the code it
# plans. Needs TERRAFORM_VERSION, TERRAFORM_SHA256 and VAULT_ADDR (the workflow's env), curl, jq
# and unzip, and the job's ID token request variables (enable-openid-connect).
#
# The credentials come from Vault for this run only: the job's ID token logs in to auth/forgejo
# as clusters-plan or clusters-apply, which only accept the runs they're for (terraform/vault),
# and the Vault token is revoked straight after. They're masked in the log, passed to Terraform
# alone, and never written to disk or to the job's environment files.

set -euo pipefail

: "${TERRAFORM_VERSION:?}" "${TERRAFORM_SHA256:?}" "${VAULT_ADDR:?}"
: "${ACTIONS_ID_TOKEN_REQUEST_URL:?no ID token, is enable-openid-connect set?}" "${ACTIONS_ID_TOKEN_REQUEST_TOKEN:?}"

action="${1:-}"
checkout="${2:-}"
if [[ ! "$action" =~ ^(plan|apply)$ || ! -d "$checkout/terraform/clusters" ]]; then
  echo "Usage: $(basename "$0") <plan|apply> <checkout>"
  exit 1
fi

tmp=$(mktemp -d)
vault_token=""

function revoke_vault_token {
  if [[ -n "$vault_token" ]]; then
    curl -fsS -o /dev/null -X POST -H "X-Vault-Token: $vault_token" "$VAULT_ADDR/v1/auth/token/revoke-self" || true
    vault_token=""
  fi
}

# The plan file holds secrets too.
function cleanup {
  revoke_vault_token
  rm -rf "$tmp"
}
trap cleanup EXIT

# Hidden from the job's log from here on (the runner replaces it with ***).
function mask {
  echo "::add-mask::$1"
}

# Terraform, checked against the pinned checksum.
curl -fsSLo "$tmp/terraform.zip" \
  "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
echo "$TERRAFORM_SHA256  $tmp/terraform.zip" | sha256sum -c -
unzip -q "$tmp/terraform.zip" terraform -d "$tmp"

# --- Credentials -------------------------------------------------------------------------------

# The job's ID token, for Vault (the audience its roles expect). Its claims are what Vault decides
# on, so they're shown (the claims, not the token).
id_token=$(curl -fsS -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=$VAULT_ADDR" | jq -r .value)
mask "$id_token"
echo "ID token claims:"
jq -R 'split(".")[1] | gsub("-"; "+") | gsub("_"; "/") | @base64d | fromjson | del(.exp, .iat, .nbf)' <<< "$id_token"

login=$(jq -n --arg role "clusters-$action" --arg jwt "$id_token" '{role: $role, jwt: $jwt}' |
  curl -sS -X POST --data @- "$VAULT_ADDR/v1/auth/forgejo/login")
unset id_token
vault_token=$(jq -r '.auth.client_token // empty' <<< "$login")
if [[ -z "$vault_token" ]]; then
  # Says which claim didn't match.
  echo "Vault refused this run: $(jq -r '.errors // [] | join("; ")' <<< "$login")"
  exit 1
fi
mask "$vault_token"
unset login

secrets=$(curl -fsS -H "X-Vault-Token: $vault_token" "$VAULT_ADDR/v1/labv2/data/ci/clusters" | jq .data.data)
revoke_vault_token
pm_password=$(jq -r .PM_PASSWORD <<< "$secrets")
pg_password=$(jq -r .PG_PASSWORD <<< "$secrets")
unset secrets
mask "$pm_password"
mask "$pg_password"

# --- Terraform ---------------------------------------------------------------------------------

function tf {
  "$tmp/terraform" -chdir="$checkout/terraform/clusters" "$@"
}

export TF_IN_AUTOMATION=1 TF_INPUT=0
export TF_VAR_pm_user="root@pam"
export TF_VAR_pm_password="$pm_password"
export PG_CONN_STR="postgres://terraform_ci:$pg_password@git.hirednoobs.com/terraform?sslmode=verify-full"
unset pm_password pg_password

# Providers as the committed lock file has them, nothing else.
tf init -lockfile=readonly

# A workstation's run holds the state's lock: wait for it rather than fail.
if [[ "$action" == "plan" ]]; then
  tf plan -lock-timeout=15m
else
  tf plan -lock-timeout=15m -out="$tmp/tfplan"
  # One at a time so Talos upgrades don't take down several nodes at once (as build.sh).
  tf apply -lock-timeout=15m -parallelism=1 "$tmp/tfplan"
fi
