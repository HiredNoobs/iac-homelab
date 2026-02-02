#!/usr/bin/env bash

cd terraform

terraform init -upgrade
terraform validate
terraform plan

echo "Apply Terraform? [y/N]"
read -r CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Applying terraform changes"
  terraform apply
else
  echo "Not applying Terraform changes and skipping ansible config"
  exit 0
fi

terraform apply

cd ../playbooks

ansible-playbook -i inventory.yml keepalived.yml
ansible-playbook -i inventory.yml swarm.yml
