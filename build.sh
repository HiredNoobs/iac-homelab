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

  echo "Apply Terraform? [y/N]"
  read -r confirm

  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Applying terraform changes"
    terraform apply -auto-approve
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
  done
  cd "$HERE" || exit 1
}

# -----------------------------------------------------
# Main
# -----------------------------------------------------

run_terraform

run_playbooks \
  readycheck.yml \
  autologin.yml \
  patch.yml \
  swarm.yml \
  keepalived.yml \
  movein.yml
