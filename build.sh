#!/usr/bin/env bash

THIS=$(realpath "$0")
HERE=$(dirname "$THIS")

# Terraform root in terraform/.
ROOT=""

# Passed to every ansible-playbook run.
ANSIBLE_ARGS=()

# Playbooks run after each root's Terraform, in order, limited to the hosts in LIMIT.
#
# The clusters root has no hosts of its own, mgmt.yml copies its talosconfigs to the management
# VMs (in the gitops root) and refreshes their kubeconfigs.
CLUSTERS_LIMIT=mgmt
CLUSTERS_PLAYBOOKS=(
  mgmt.yml
)

GITOPS_LIMIT=gitops
GITOPS_PLAYBOOKS=(
  readycheck.yml
  movein.yml
  patch.yml
  monitoring.yml
  fail2ban.yml
  vault.yml
  forgejo.yml
  forgejo-runner.yml
  forgejo-repos.yml
  terraform-state.yml
  backups.yml
  mgmt.yml
)

# Vault's config has no hosts, nothing runs after it.

# The clusters and vault roots keep their state in Postgres on the git VM (terraform-state.yml),
# as this database role unless PG_CONN_STR is already set. The gitops root's stays here, in
# terraform/gitops/, with a copy on the NAS after each apply (smbclient, as NAS_USER).
STATE_HOST=git.hirednoobs.com
STATE_DATABASE=terraform
STATE_ROLE=terraform
NAS_SHARE=//192.168.111.6/terraform-state
NAS_USER=terraform

# -----------------------------------------------------
# Functions
# -----------------------------------------------------

function usage {
  echo "Usage: $(basename "$0") <clusters|gitops|vault> [--refresh-keys]"
  echo
  echo "  clusters        The prx-00x Talos clusters, then mgmt.yml on the management VMs."
  echo "  gitops          The prx-999 VMs (management, Vault, Forgejo, runners)."
  echo "  vault           Vault's config (secret engines, policies, auth), Vault must be unsealed."
  echo "  --refresh-keys  Forget the hosts' old SSH host keys before connecting, for rebuilt VMs."
}

function run_terraform {
  local confirm

  cd "$HERE/terraform/$ROOT" || exit 1

  # Providers come from the committed .terraform.lock.hcl, bump them deliberately.
  terraform init
  terraform validate || exit 1
  # Saved so the apply is exactly what was reviewed, it contains secrets and is git ignored.
  terraform plan -out=tfplan || exit 1

  read -r -p "Apply Terraform? [y/N]: " confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Applying terraform changes"
    # One at a time so Talos upgrades don't take down several nodes at once.
    terraform apply -parallelism=1 tfplan || exit 1
  else
    echo "Skipping build."
    rm -f tfplan
    exit 0
  fi

  rm -f tfplan
  [[ "$ROOT" == "clusters" ]] && write_cluster_files
  [[ "$ROOT" == "gitops" ]] && copy_gitops_state
  cd "$HERE" || exit 1
}

# The talosconfigs (~/.talos/contexts/<context>.yaml, where tools-bin's context-setup reads them)
# and the clusters' part of the Ansible inventory, from the outputs: CI applies the same state, so
# Terraform writes no files itself.
function write_cluster_files {
  local talosconfigs context dir="$HOME/.talos/contexts"

  talosconfigs=$(terraform output -json talosconfigs) || exit 1
  mkdir -p "$dir" && chmod 700 "$dir"
  for context in $(jq -r 'keys[]' <<< "$talosconfigs"); do
    (umask 077 && jq -j --arg context "$context" '.[$context]' <<< "$talosconfigs" > "$dir/$context.yaml") || exit 1
  done

  # JSON is YAML too.
  terraform output -json ansible_vars | jq --arg dir "$dir" --argjson talosconfigs "$talosconfigs" \
    '{all: {vars: (. + {talosconfigs: ($talosconfigs | with_entries(.value = "\($dir)/\(.key).yaml"))})}}' \
    > "$HERE/playbooks/inventory/clusters.generated.yml" || exit 1
}

# The gitops root's state to the NAS, named like the git VM's copies of the others. A failure
# doesn't stop the build (the apply is done), but needs fixing: this is the only other copy.
function copy_gitops_state {
  local name

  name="$(date -u +%Y%m%dT%H%M%SZ)-$(jq -r .serial terraform.tfstate).tfstate"
  if PASSWD=$(cat "$HERE/secrets/nas-terraform-state") \
    smbclient "$NAS_SHARE" -U "$NAS_USER" -D gitops -c "put terraform.tfstate $name"; then
    echo "Copied the gitops state to $NAS_SHARE/gitops/$name"
  else
    echo "WARNING: the gitops state wasn't copied to the NAS, copy terraform/gitops/terraform.tfstate by hand."
  fi
}

function run_playbooks {
  local limit="$1" hosts
  shift

  cd "$HERE/playbooks" || exit 1

  # e.g. no management VM yet, while it's being replaced.
  hosts=$(ansible "$limit" --list-hosts 2> /dev/null | grep -c "^    [^ ]")
  if [[ -z "$hosts" || "$hosts" == "0" ]]; then
    echo "No hosts in '$limit', skipping the playbooks."
    cd "$HERE" || exit 1
    return 0
  fi

  for playbook in "$@"; do
    echo "Running $playbook..."
    # The inventory holds every root's hosts, only touch these.
    ansible-playbook "$playbook" --limit "$limit" "${ANSIBLE_ARGS[@]}" || {
      echo "$playbook failed, aborting."
      exit 1
    }
  done
  cd "$HERE" || exit 1
}

# -----------------------------------------------------
# Main
# -----------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    clusters|gitops|vault) ROOT="$1"; shift;;
    --refresh-keys) ANSIBLE_ARGS+=(-e refresh_host_keys=true); shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

if [[ -z "$ROOT" ]]; then
  usage
  exit 1
fi

# The root token, unless another token was given.
if [[ "$ROOT" == "vault" && -z "${VAULT_TOKEN:-}" ]]; then
  VAULT_TOKEN=$(jq -r .root_token "$HERE/secrets/vault-keys.json") || exit 1
  export VAULT_TOKEN
fi

if [[ "$ROOT" != "gitops" && -z "${PG_CONN_STR:-}" ]]; then
  PG_CONN_STR="postgres://$STATE_ROLE:$(cat "$HERE/secrets/postgres-password")@$STATE_HOST/$STATE_DATABASE?sslmode=verify-full" || exit 1
  export PG_CONN_STR
fi

run_terraform

case "$ROOT" in
  clusters) run_playbooks "$CLUSTERS_LIMIT" "${CLUSTERS_PLAYBOOKS[@]}";;
  gitops) run_playbooks "$GITOPS_LIMIT" "${GITOPS_PLAYBOOKS[@]}";;
esac
