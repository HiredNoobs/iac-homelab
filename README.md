# iac-homelab

Terraform and Ansible for the homelab: the Talos Kubernetes clusters on the ``prx-00x`` Proxmox hosts, and the servers that manage them (management, Vault, Forgejo, runners) on the standalone ``prx-999`` host.

| Terraform root | Builds | Playbooks |
| --- | --- | --- |
| ``terraform/clusters/`` | The Talos clusters. | ``mgmt.yml`` on the management VMs, to copy the new talosconfigs. |
| ``terraform/gitops/`` | The ``prx-999`` Debian VMs. | All of them, on the ``prx-999`` VMs. |
| ``terraform/vault/`` | Vault's config: secret engines, policies, auth (Kubernetes for ESO). | None. |

Each root has its own state and writes its part of the Ansible inventory to ``playbooks/inventory/``. Nothing in the clusters root depends on ``prx-999``, so the clusters can always be rebuilt from a workstation.

## Usage

Install Terraform (the exact ``required_version`` in ``terraform/*/versions.tf``) and Ansible. Both roots use the Proxmox root account of the host they talk to (``prx-001`` for clusters, ``prx-999`` for gitops):

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
- Applying by hand: ``terraform apply -parallelism=1`` from ``terraform/<root>/``.

**The state contains secrets (the cluster CAs and keys) and is git ignored.** Keep a backup, without it Terraform can't manage the clusters.

## Clusters

Defined in ``terraform/clusters/clusters.auto.tfvars``, keyed by the tools-bin context name (e.g. ``production.core``). The node name sets the Proxmox node, role and labels: ``prx-002-srv-prod-core-worker-001`` is a worker on ``prx-002`` with ``topology.kubernetes.io/zone: prx-002`` and ``hirednoobs.com/pool: worker-001``.

- VMIDs per Proxmox node (``prx-001`` = 100-199): X00-X09 control planes, X10-X89 workers.
- IPs: ``.10`` API VIP, ``.11``-``.99`` nodes, ``.100``-``.149`` LoadBalancer IPs (kube-vip).
- ``longhorn_disk`` adds a disk at ``/var/mnt/longhorn`` and the ``node.longhorn.io/create-default-disk=true`` label.
- The talosconfigs are written to ``~/.talos/contexts/<context>.yaml``, they're the way in if the management VMs are down.

## prx-999

VMs are defined in ``terraform/gitops/servers.auto.tfvars`` as ``prx-999-srv-<role>-<number>``, the role is the Ansible group. Servers count up from 900 / ``.200``, management VMs down from 999 / ``.254``.

| VM | Role | Runs |
| --- | --- | --- |
| ``prx-999-srv-mgmt-001`` | ``mgmt`` | The jumpbox: tools-bin, ``talosctl`` and ``kubectl`` for every cluster. |
| ``prx-999-srv-git-001`` | ``git`` | Forgejo at ``https://git.hirednoobs.com``. |
| ``prx-999-srv-runner-001`` | ``runner`` | forgejo-runner, jobs in Docker. No infrastructure credentials. |
| ``prx-999-srv-vault-001`` | ``vault`` | Vault at ``https://vault.hirednoobs.com``. |

### prerequisites

Add ``git`` (``.200``) and ``vault`` (``.202``) to the router's DNS, see ``HiredNoobs/documentation/network/router.md``. stack-pihole has the same records.

### Bootstrap secrets

Files in ``secrets/``, on the machine running Ansible.

| File | Used for |
| --- | --- |
| ``cloudflare-api-token`` | certbot (DNS-01). Zone.DNS:Edit on ``hirednoobs.com`` only. |
| ``vault-keys.json`` | Vault's unseal keys and root token.|
| ``forgejo-admin-password`` | Creates the first Forgejo admin. |
| ``forgejo-runner-<host>`` | A runner's registration secret, ``openssl rand -hex 20``, one per runner. |
| ``forgejo-api-token`` | ``forgejo-repos.yml``. An admin's Forgejo token (``write:repository``, ``read:user``), created in the UI. |
| ``github-mirror-token`` | Importing the IaC repos and push-mirroring them to GitHub. A fine-grained token for those repos: Contents read/write, Metadata, Issues and Pull requests read. Note its expiry. |

### Vault

Vault starts sealed after every restart. Unseal it with ``ansible-playbook vault-unseal.yml``.

A new, empty Vault is initialised on the VM, save the output as ``secrets/vault-keys.json``:

```bash
vault operator init -key-shares=4 -key-threshold=3 -format=json \
  | jq '{keys: .unseal_keys_hex, keys_base64: .unseal_keys_b64, root_token: .root_token}'
```

### Vault config

``terraform/vault/`` configures Vault, not the VM, so it's its own root: the provider needs Vault up and unsealed to plan. It manages the ``lab`` (kv) and ``labv2`` (kv v2) engines, the userpass auth mount, the policies and a Kubernetes auth mount per cluster (``kubernetes/<cluster>``) for External Secrets Operator in iac-k8s. ESO can only read ``labv2/<environment>/*``. The secrets aren't managed here.

- Each cluster in ``clusters.auto.tfvars`` needs its API server's CA, from the management VM. The CA is public, commit it. Re-run it if the cluster is rebuilt:

  ```bash
  kubectl --kubeconfig "$KUBE_CONTEXTS/production.core.yaml" config view --raw \
    -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d \
    > terraform/vault/clusters/production-core-ca.crt
  ```

- ``imports.tf`` imports what stack-vault created. Check the plan only imports them (and shows no replacement), then delete the file after the first apply. The mounts can't be destroyed by Terraform (``prevent_destroy``), replacing one deletes its secrets.
- Users are added by hand, so their passwords stay out of the state: ``vault write auth/userpass/users/<name> token_policies=lab-policy,labv2-policy password=-`` (reads the password from stdin).

### Forgejo

Only the IaC repos (this one, later the Flux repo) live on Forgejo, everything else stays on GitHub with GitHub's Actions. Forgejo is their upstream: clone from ``git@git.hirednoobs.com:hirednoobs/<repo>.git`` (add your SSH key in the UI), every push is mirrored to the GitHub repo, which is read-only.

``forgejo-repos.yml`` sets them up from ``forgejo_repos`` in ``playbooks/roles/forgejo_repos/defaults/main.yml``: imports the repo from GitHub (history, issues, PRs, releases) if it's missing, adds the push mirror and protects ``master`` from force pushes. Before adding a repo, disable Actions on its GitHub repo and remove any GitHub branch protection (the mirror pushes to it). After rotating ``github-mirror-token``, run ``ansible-playbook forgejo-repos.yml -e forgejo_repos_update_mirror_credentials=true``.

- Workflows go in ``.forgejo/workflows/`` and use ``runs-on: docker``. There are no actions: ``uses:`` resolves against Forgejo (``DEFAULT_ACTIONS_URL = self``, so nothing is fetched from GitHub), but the runner clones actions without a token and ``REQUIRE_SIGNIN_VIEW`` refuses it. Check out with ``git`` and the job token, and install tools with a pinned checksum (see ``lint.yml``).
- Only code pushed to Forgejo runs CI. Disable Actions on the GitHub push mirrors, and never enable Actions on a pull mirror (a sync counts as a push).
- To re-register a runner, delete ``/var/lib/forgejo-runner/.runner`` on it and run ``forgejo.yml`` and ``forgejo-runner.yml``.
- Back up the database (``pg_dump``), ``/var/lib/forgejo`` and ``/etc/forgejo/secrets`` together.

## Upgrades

- Talos: bump ``talos_version``, the nodes are upgraded in place one at a time. Don't change ``talos_contract``.
- Kubernetes: bump ``kubernetes_version``.
- Vault, Forgejo, forgejo-runner, node_exporter: bump the version and its checksum together in the role's ``defaults/main.yml``. A Vault restart seals it.
- Lint CI: the tool versions and checksums in ``.forgejo/workflows/lint.yml``, ansible-core in ``.forgejo/requirements-lint.txt`` (regenerate it, see its header).
- Terraform providers: bump the version, then ``terraform init -upgrade`` and ``terraform providers lock -platform=linux_amd64``.
