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
  terraform validate
  terraform plan

  read -r -p "Apply Terraform? [y/N]: " confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Applying terraform changes"
    terraform apply -auto-approve -parallelism=1 || exit 1
  else
    echo "Skipping build."
    exit 0
  fi

  cd "$HERE" || exit 1
}

function run_playbooks {
  cd "$HERE/playbooks" || exit 1
  for playbook in "$@"; do
    echo "Running $playbook..."
    ansible-playbook -i inventory.generated.yml "$playbook" || {
      echo "$playbook failed, aborting."
      exit 1
    }
    # Probably not necessary but some of these playbooks
    # do restart the host, reload services, etc.
    echo "Waiting for services to stabilise..."
    sleep 10
  done
  cd "$HERE" || exit 1
}

# -----------------------------------------------------
# Main
# -----------------------------------------------------

run_terraform

run_playbooks \
  readycheck.yml \
  patch.yml \
  monitoring.yml \
  swarm.yml \
  keepalived.yml \
  movein.yml \
  fail2ban.yml
