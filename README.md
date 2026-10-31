# iac-homelab

Terraform and Ansible for the homelab: the Talos Kubernetes clusters on the ``prx-00x`` Proxmox hosts, and the servers that manage them (management, Vault, Forgejo, runners) on the standalone ``prx-999`` host.

| Terraform root | Builds | Playbooks |
| --- | --- | --- |
| ``terraform/clusters/`` | The Talos clusters. | ``mgmt.yml`` on the management VMs, to copy the new talosconfigs. |
| ``terraform/gitops/`` | The ``prx-999`` Debian VMs. | All of them, on the ``prx-999`` VMs. |
| ``terraform/vault/`` | Vault's config: secret engines, policies, auth (Kubernetes for ESO, Forgejo ID tokens for CI, an AppRole for the Vault backup). | None. |

Each root has its own state (see [Terraform state](docs/terraform-state.md)) and its part of the Ansible inventory in ``playbooks/inventory/`` (the clusters root's is written by ``build.sh`` from its outputs). Nothing in the clusters root depends on ``prx-999``, so the clusters can always be rebuilt without it. Changes to the clusters root go through pull requests: CI plans them and applies them when merged (see [CI](docs/ci.md)).

## Usage

Install Terraform (the exact ``required_version`` in ``terraform/*/versions.tf``), Ansible, ``jq`` and ``smbclient``. Both roots use the Proxmox root account of the host they talk to (``prx-001`` for clusters, ``prx-999`` for gitops):

```bash
export TF_VAR_pm_user="root@pam"
export TF_VAR_pm_password="<password for that root's Proxmox>"

# plan, confirm, apply, then the playbooks
./build.sh <clusters|gitops> [--refresh-keys]
./teardown.sh <clusters|gitops>

# Vault must be unsealed, logs in with the root token from secrets/vault-keys.json (or VAULT_TOKEN)
./build.sh vault
```

- ``--refresh-keys`` forgets the old SSH host keys, for rebuilt VMs.
- Playbooks can be run on their own from ``playbooks/``. Tasks handling secrets hide their output, ``-e show_secrets=true`` shows it when debugging.
- ``./build.sh gitops`` runs ``patch.yml``, which may reboot the Vault VM: unseal it afterwards.
- Building from scratch: see [Rebuilding from nothing](docs/rebuild.md) (the order, and ``TF_VAR_metrics_server_enabled=false`` until vmagent is up).
- Applying by hand: ``terraform apply -parallelism=1`` from ``terraform/<root>/``, with ``PG_CONN_STR`` set for clusters and vault (as ``state.sh`` builds it).

## Clusters

Defined in ``terraform/clusters/clusters.auto.tfvars``, keyed by the tools-bin context name (e.g. ``production.core``). The node name sets the Proxmox node, role and labels: ``prx-002-srv-prod-core-worker-001`` is a worker on ``prx-002`` with ``topology.kubernetes.io/zone: prx-002`` and ``hirednoobs.com/pool: worker-001``.

- VMIDs per Proxmox node (``prx-001`` = 100-199): X00-X09 control planes, X10-X89 workers.
- IPs: ``.10`` API VIP, ``.11``-``.99`` nodes (``.X1``-``.X9`` on ``prx-00X``, control plane first), ``.100``-``.149`` LoadBalancer IPs (kube-vip).
- ``longhorn_disk`` adds a disk at ``/var/mnt/longhorn`` and the ``node.longhorn.io/create-default-disk=true`` label.
- ``./build.sh clusters`` writes the talosconfigs to ``~/.talos/contexts/<context>.yaml`` after an apply (from the ``talosconfigs`` output, ``terraform output -json talosconfigs`` gets them any time), they're the way in if the management VMs are down.

## More

| Page | Covers |
| --- | --- |
| [Rebuilding from nothing](docs/rebuild.md) | What's done by hand, the order across the repos, where the data comes back from. |
| [CI](docs/ci.md) | The workflows, and how the clusters workflow gets its credentials from Vault. |
| [Terraform state](docs/terraform-state.md) | Where each root's state lives, its copies on the NAS, setting it up, break-glass. |
| [Backups](docs/backups.md) | What's backed up to the NAS, setting it up, restoring Vault and Forgejo. |
| [prx-999](docs/prx-999.md) | The VMs, their bootstrap secrets, Vault and its config, Forgejo. |

## Upgrades

Renovate (the renovate repo) opens a pull request for each, a version and its checksum together: Talos and Kubernetes (``talos_version``, ``kubernetes_version``, a minor at a time), Terraform and its providers with the lock files, the roles' Vault, Forgejo, forgejo-runner, node_exporter and Vector, the lint tools and ansible-core. A clusters change is applied by merging it (see [CI](docs/ci.md)), the rest with ``build.sh`` afterwards.

- Talos: the nodes are upgraded in place one at a time. Don't change ``talos_contract``.
- A Vault restart seals it, unseal it after ``./build.sh gitops``.
- By hand: a role's version and checksum in its ``defaults/main.yml``, the lint tools' in ``.forgejo/workflows/lint.yml``, ansible-core in ``.forgejo/requirements-lint.in`` (then regenerate ``requirements-lint.txt``, see its header), a provider's version then ``terraform init -upgrade`` and ``terraform providers lock -platform=linux_amd64``.
