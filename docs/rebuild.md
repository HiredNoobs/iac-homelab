# Rebuilding from nothing

Everything is rebuilt from a Linux machine outside the Proxmox hosts, never from the management VM, which is one of the things being built. The code is this repo, iac-k8s (applied by Flux), tools-bin and the renovate repo. What isn't code has to come from somewhere else:

| What | From |
| --- | --- |
| ``secrets/`` | The copy kept away from prx-999 (see [Backups](backups.md)). Without ``vault-keys.json`` Vault's snapshots can't be read, without ``restic-forgejo`` Forgejo's backups can't. |
| Vault's secrets, Forgejo, the Terraform state | Their backups on the NAS ([Backups](backups.md), [Terraform state](terraform-state.md)). |
| The clusters' volumes (Grafana, Authelia, LLDAP, Vaultwarden, ...) | Longhorn's nightly backups on the NAS (iac-k8s ``docs/rebuild.md``). |

Losing only part of it is the same order with the steps that aren't needed left out: a cluster alone is steps 1, 4 and 5 (the clusters root needs nothing from prx-999, with its state copied from the NAS if the git VM is down, see [Break-glass](terraform-state.md#break-glass)); prx-999 alone is steps 1 to 3.

## Done by hand

Nothing here is automated (no automation on the router or the NAS, the Proxmox hosts only through their API):

- **Proxmox VE** on ``prx-001``..``prx-003`` (one Proxmox cluster) and ``prx-999`` (standalone): the root password, the bridge ``vmbr0`` in VLAN 111 (``192.168.111.0/24``), storage ``local`` for images and ``vmdata`` (``prx-00x``) or ``local-lvm`` (``prx-999``) for disks. The roots talk to ``https://192.168.111.2:8006`` (``prx-001``) and ``https://192.168.111.9:8006`` (``prx-999``). Terraform does the rest the API offers (APT repositories, the metric server).
- **The router** (``HiredNoobs/documentation/network/router.md``): DNS records for ``git`` and ``vault``, Pi-hole (``192.168.111.100``) as the DNS server DHCP hands out, and the rest of what's written there. The VMs and Talos nodes resolve through the router, not Pi-hole, so nothing here waits for the cluster.
- **The NAS**: a share and a user of its own for each of ``terraform-state``, ``vault-backups``, ``forgejo-backups`` and ``longhorn-backups``.
- **Accounts outside**: the Cloudflare API tokens (certbot's in ``secrets/``, cert-manager's in Vault), the GitHub repos Forgejo mirrors to and their token, Docker Hub, healthchecks.io and ntfy (Alertmanager's, in Vault).

## Order

1. **The machine running the build.** Terraform (the exact ``required_version`` in ``terraform/*/versions.tf``), Ansible (the ansible-core version in ``.forgejo/requirements-lint.txt``), ``jq``, ``smbclient``, and ``~/.ssh/id_rsa.pub`` (the VMs' admin key). ``secrets/`` back in place. tools-bin cloned, its ``context-setup`` brings ``talosctl``, ``kubectl``, ``flux`` and ``vault`` at the pinned versions once there are clusters (step 4).
2. **prx-999.** With ``TF_VAR_pm_user``/``TF_VAR_pm_password`` for ``prx-999`` (see the README) and ``TF_VAR_metrics_server_enabled=false`` (Proxmox won't add a metric server that doesn't answer yet): ``./build.sh gitops``. It builds the VMs and runs every playbook; the last, ``mgmt.yml``, waits about 5 minutes for the clusters and fails if they aren't up yet, which is expected here (step 4 runs it again). Then:
   - **Vault**: restore its snapshot ([Restoring Vault](backups.md#restoring-vault)), or initialise an empty one ([prx-999](prx-999.md#vault)) and put every secret back by hand (the list is in iac-k8s ``docs/rebuild.md``, plus ``labv2/ci/clusters`` for [CI](ci.md) and the userpass users). Unseal it with ``ansible-playbook vault-unseal.yml``.
   - **Forgejo**: restore it ([Restoring Forgejo](backups.md#restoring-forgejo)). Without a backup, ``forgejo-repos.yml`` has already imported iac-homelab and iac-k8s from their GitHub mirrors, without the issues and pull requests made on Forgejo, and the renovate repo, which is only on Forgejo, is gone: recreate it from a clone. Recreate by hand what Forgejo held that isn't in a repo: your SSH key, the ``flux-bot`` and ``renovate-bot`` users and their tokens (iac-k8s ``docs/flux.md``, the renovate repo's README), the renovate repo's secrets.
   - **Terraform state**: the git VM's Postgres starts empty. Push the clusters and vault states back from their NAS copies (the end of [Break-glass](terraform-state.md#break-glass)).
3. **Vault's config.** ``./build.sh vault`` (Forgejo must be up: Vault fetches its keys for ``auth/forgejo``). Then ``ansible-playbook backups.yml`` from ``playbooks/``, which needs the AppRole this created.
4. **The clusters.** With ``prx-001``'s credentials and still ``TF_VAR_metrics_server_enabled=false``: ``./build.sh clusters``. It writes the talosconfigs to ``~/.talos/contexts/``, copies them to the management VM and runs ``context-setup`` there (``mgmt.yml``); run ``context-setup`` on the machine running the build too for its kube contexts. A rebuilt cluster has a new CA: export it into ``terraform/vault/clusters/`` ([Vault config](prx-999.md#vault-config)), merge it, and ``./build.sh vault`` again, or External Secrets Operator can't log in to Vault.
5. **What runs on the clusters.** Flux, from iac-k8s: its ``docs/rebuild.md`` (bootstrap, the secrets it needs, restoring the volumes).
6. **The metric servers.** Once Flux has deployed vmagent: ``./build.sh gitops`` and ``./build.sh clusters`` without ``TF_VAR_metrics_server_enabled``, so the Proxmox hosts send their metrics again.
7. **Renovate.** The renovate repo's workflow runs once its secrets are set (its README); check its first run's log and the Dependency Dashboard issues.

## Checks

- ``./build.sh gitops`` and ``./build.sh clusters`` plan no changes.
- Vault is unsealed and ``vault-backup`` runs (``sudo systemctl start vault-backup`` on the vault VM), as does ``forgejo-backup`` on the git VM.
- A pull request on iac-homelab gets its plan from CI (the clusters workflow logs in to Vault).
- ``flux get kustomizations`` is all Ready, ``kubectl get externalsecrets -A`` all ``SecretSynced``, and Grafana's dashboards fill (the Proxmox ones once step 6 is done).
