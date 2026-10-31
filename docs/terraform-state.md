# Terraform state

**The state contains secrets (the cluster CAs and keys).** Without it Terraform can't manage what it built.

| Root | State | Copies |
| --- | --- | --- |
| ``clusters``, ``vault`` | Postgres on the git VM, database ``terraform``, one schema per root (the ``pg`` backend). | The git VM copies each state to the NAS within the hour of a change. |
| ``gitops`` | ``terraform/gitops/terraform.tfstate`` on the machine running ``build.sh``, git ignored. Applying this root can rebuild the git VM, so its state can't live there. | ``build.sh gitops`` copies it to the NAS after each apply. |

The vault root could keep its state with gitops, but applying it never touches a VM, so Postgres is safe. Only the clusters root is ever applied by CI.

- ``build.sh`` connects as ``terraform`` (``secrets/postgres-password``), over TLS (``git.hirednoobs.com``'s Let's Encrypt certificate, ``sslmode=verify-full``). ``terraform-state.yml`` sets up the database, its roles, the listener and the copies; who may connect from where is ``terraform_state_clients`` in ``playbooks/roles/terraform_state/defaults/main.yml``.
- The copies are on the NAS share ``terraform-state``, ``<root>/<UTC time>-<serial>.tfstate``: the newest 20 per root are kept, older ones for 90 days. They're plain state files, readable by anyone with the share's password.
- A failed copy on the git VM fails ``terraform-state-export.service`` (``HostSystemdServiceCrashed`` alerts). ``journalctl -u terraform-state-export`` lists what it copied.

## Setting up

1. On the NAS (by hand): a share ``terraform-state`` and a user ``terraform`` with read/write on that share only. Its password goes in ``secrets/nas-terraform-state`` (no special characters, it's a mount option).
2. ``openssl rand -hex 32 > secrets/postgres-password``.
3. ``ansible-playbook terraform-state.yml`` from ``playbooks/`` (``build.sh gitops`` runs it too).
4. Move each state in: from ``terraform/<root>/`` with ``PG_CONN_STR`` set (as in ``state.sh``), ``terraform init -migrate-state``, answer yes, check ``terraform plan`` shows no changes, then delete the local ``terraform.tfstate*``.

## Break-glass

Without Postgres (the git VM or prx-999 down), from a copy on the NAS:

```bash
cd terraform/clusters
cp /path/to/terraform-state/clusters/<newest>.tfstate terraform.tfstate
cat > backend_override.tf <<'EOF'
terraform {
  backend "local" {}
}
EOF
terraform init -reconfigure
terraform plan
```

Once Postgres is back, push the state up before removing the override: ``rm backend_override.tf``, ``terraform init -migrate-state`` (it offers to copy the local state), then delete ``terraform.tfstate*``. ``*_override.tf`` is git ignored. Rebuilding prx-999 itself is ``build.sh gitops`` with the gitops state (local, or its copy on the NAS); the git VM's database starts empty, so push the clusters and vault states back the same way.
