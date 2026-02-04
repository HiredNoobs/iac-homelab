#!/usr/bin/env bash

cd terraform

terraform init -upgrade
terraform validate
terraform plan

echo "Apply Terraform? [y/N]"
read -r CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Applying terraform changes"
  terraform apply -auto-approve
else
  echo "Not applying Terraform changes and skipping ansible config"
  exit 0
fi

echo "Sleeping for 30s"
sleep 30

cd ../playbooks

echo "Configuring autologin..."
ansible-playbook -i inventory.generated.yml autologin.yml

echo "Patching host..."
ansible-playbook -i inventory.generated.yml patch.yml

echo "Configuring user and default packages..."
ansible-playbook -i inventory.generated.yml movein.yml

echo "Configuring keepalived..."
ansible-playbook -i inventory.generated.yml keepalived.yml

echo "Configuring Docker Swarms..."
ansible-playbook -i inventory.generated.yml swarm.yml
