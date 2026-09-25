#!/usr/bin/env bash

THIS=$(realpath "$0")
HERE=$(dirname "$THIS")

# Passed to every ansible-playbook run.
ANSIBLE_ARGS=()

# -----------------------------------------------------
# Functions
# -----------------------------------------------------

function usage {
  echo "Usage: $(basename "$0") [--refresh-keys]"
  echo
  echo "  --refresh-keys  Forget the hosts' old SSH host keys before connecting, for rebuilt VMs."
}

function run_terraform {
  local confirm

  cd "$HERE/terraform" || exit 1

  terraform init -upgrade
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
    ansible-playbook "$playbook" "${ANSIBLE_ARGS[@]}" || {
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
    --refresh-keys) ANSIBLE_ARGS+=(-e refresh_host_keys=true); shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1"; usage; exit 1;;
  esac
done

run_terraform

run_playbooks \
  readycheck.yml \
  movein.yml \
  patch.yml \
  monitoring.yml \
  fail2ban.yml \
  mgmt.yml
