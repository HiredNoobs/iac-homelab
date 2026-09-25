#!/usr/bin/env bash

THIS=$(realpath "$0")
HERE=$(dirname "$THIS")

# -----------------------------------------------------
# Functions
# -----------------------------------------------------

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
    ansible-playbook "$playbook" || {
      echo "$playbook failed, aborting."
      exit 1
    }
  done
  cd "$HERE" || exit 1
}

# -----------------------------------------------------
# Main
# -----------------------------------------------------

run_terraform

run_playbooks \
  readycheck.yml \
  movein.yml \
  patch.yml \
  monitoring.yml \
  fail2ban.yml \
  mgmt.yml
