#!/usr/bin/env bash

THIS=$(realpath "$0")
HERE=$(dirname "$THIS")

# Terraform root in terraform/, also the Ansible group its hosts are in.
ROOT=""

# Passed to every ansible-playbook run.
ANSIBLE_ARGS=()

# Playbooks run after each root's Terraform, in order.
CLUSTERS_PLAYBOOKS=(
  readycheck.yml
  movein.yml
  patch.yml
  monitoring.yml
  fail2ban.yml
  mgmt.yml
)

GITOPS_PLAYBOOKS=(
  readycheck.yml
  movein.yml
  patch.yml
  monitoring.yml
  fail2ban.yml
  vault.yml
  forgejo.yml
  forgejo-runner.yml
)

# -----------------------------------------------------
# Functions
# -----------------------------------------------------

function usage {
  echo "Usage: $(basename "$0") <clusters|gitops> [--refresh-keys]"
  echo
  echo "  clusters        The prx-00x Talos clusters and their management VMs."
  echo "  gitops          The prx-999 VMs (Vault, Forgejo, runners)."
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
  cd "$HERE" || exit 1
}

function run_playbooks {
  cd "$HERE/playbooks" || exit 1
  for playbook in "$@"; do
    echo "Running $playbook..."
    # The inventory holds every root's hosts, only touch this root's.
    ansible-playbook "$playbook" --limit "$ROOT" "${ANSIBLE_ARGS[@]}" || {
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
    clusters|gitops) ROOT="$1"; shift;;
    --refresh-keys) ANSIBLE_ARGS+=(-e refresh_host_keys=true); shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

if [[ -z "$ROOT" ]]; then
  usage
  exit 1
fi

run_terraform

case "$ROOT" in
  clusters) run_playbooks "${CLUSTERS_PLAYBOOKS[@]}";;
  gitops) run_playbooks "${GITOPS_PLAYBOOKS[@]}";;
esac
