# iac-homelab

Proxmox IAC based setup scripts/playbooks/terraform.

## Usage

### Arch

#### Terraform

Install Terraform:

```bash
sudo pacman -S terraform
```

Set env vars:

```bash
export TF_VAR_pm_user="root@pam"
export TF_VAR_pm_password="password"
```

Setup and run Terrform:

```bash
$ cd terraform

# Setup
$ terraform init
$ terraform validate

# Dry-run
$ terraform plan

# Run
$ terraform apply

# Remove
$ terraform destroy
```

#### Ansible

Install ansible:

```bash
sudo pacman -S ansible
```

Setup env vars:

```bash
# Default password for user that is created on LXCs.
$ export MOVEIN_PASSWORD=""
```

```bash
$ cd playbooks

# Run playbooks...
$ ansible-playbook -i inventory.yml keepalived.yml
```
