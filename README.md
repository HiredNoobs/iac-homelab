# iac-homelab

Terraform and Ansible for the Talos Linux Kubernetes clusters, and the Debian management VMs that manage them, on the ``prx-00x`` Proxmox hosts, and for the GitOps servers on the standalone ``prx-999`` host.

There are two Terraform roots, each with its own state:

- ``terraform/clusters/`` - the ``prx-00x`` clusters and management VMs.
- ``terraform/gitops/`` - the ``prx-999`` VMs (Vault, Forgejo, runners). Nothing in the clusters root depends on it, so the clusters can always be rebuilt from a workstation with just the Proxmox API and a copy of the state.

Both share ``terraform/modules/`` and the playbooks. Each root writes its hosts to ``playbooks/inventory/<root>.generated.yml`` under a group named after the root, Ansible merges the files.

Terraform and Ansible run from a host outside the clusters, the management VMs (``prx-<host>-srv-mgmt-<number>``) are the jumpboxes used day to day.

## Clusters

Clusters are defined in ``terraform/clusters/clusters.auto.tfvars``, keyed by the tools-bin context name (e.g. ``production.core``). Node names are ``prx-<host>-...-<control|worker>-<number>`` and the Proxmox node, role and labels come from the name, e.g. ``prx-002-srv-prod-core-worker-001`` is a worker created on ``prx-002`` with:

- ``topology.kubernetes.io/zone: prx-002`` - spread pods across hypervisors with this.
- ``hirednoobs.com/pool: worker-001`` - pin applications to a pool of workers (one per hypervisor) with this.

Stack role labels (e.g. ``pihole_core_pihole``) are added per node with ``labels``, the stacks work out their replica counts from them.

Nodes with ``longhorn_disk`` get a second disk mounted at ``/var/mnt/longhorn`` and the ``node.longhorn.io/create-default-disk=true`` label. Install Longhorn with ``defaultDataPath: /var/mnt/longhorn`` and ``createDefaultDiskLabeledNodes: true`` so only those nodes store replicas. Pods on any node can use Longhorn volumes, the replica count is set per StorageClass (``numberOfReplicas``) and Longhorn spreads them across zones (Proxmox nodes) where it can.

Node IPs are 192.168.111.11-99, 192.168.111.100-149 is kept for the LoadBalancer IPs kube-vip announces.

VMIDs are per Proxmox node (``prx-001`` = 100-199, ``prx-002`` = 200-299, ...), X00-X09 for control planes, X10-X89 for workers and X90-X99 for the management VMs (counting down from X99).

HA is handled by Kubernetes (a control plane and each worker pool on every ``prx-00x``), not Proxmox. The provider talks to a single Proxmox API, so the ``prx-00x`` hosts should be joined into one Proxmox cluster.

Terraform:

1. Builds a Talos image with the Image Factory (extensions in ``talos_extensions``) and downloads it to each Proxmox node.
2. Creates the VMs, the static IPs are passed in via cloud-init (Talos nocloud platform).
3. Generates and applies the machine configs, bootstraps the cluster, and writes the talosconfig to ``~/.talos/contexts/<context>.yaml`` for ``context-setup k8s``.

The control plane nodes share a Layer 2 VIP (``vip``) which is the Kubernetes API endpoint. Clusters without workers allow scheduling on the control plane.

## Management

The management VMs are defined in ``terraform/clusters/management.auto.tfvars``. They're the jumpboxes with tools-bin, ``talosctl`` and ``kubectl`` set up for every cluster, they're in the ``mgmt`` Ansible group.

Names are ``prx-<host>-srv-mgmt-<number>`` (the Proxmox node comes from the name). VMIDs count down from the top of their Proxmox node's range and IPs from the top of the subnet, ``prx-001-srv-mgmt-001`` is 199 / ``192.168.111.254``, one on ``prx-002`` would be 299 / ``192.168.111.253``.

Terraform creates the VMs from the Debian 13 cloud image, cloud-init creates ``admin_user`` with the key from ``ssh_public_key_file``. Terraform also writes the Ansible inventory (``playbooks/inventory/clusters.generated.yml``), then ``build.sh clusters`` runs the playbooks:

| Playbook | Hosts | Does |
| --- | --- | --- |
| ``readycheck.yml`` | all | Waits for SSH and cloud-init, optionally forgets old host keys first (see below). |
| ``movein.yml`` | all | qemu-guest-agent, locale, tools-bin (``movein.sh``, checked out at ``tools_bin_version``, then ``setup bash vim tmux``), SSH keys (each mgmt host's key is authorized on every other host, never the other way round), key-only sshd, passwordless login on the Proxmox consoles. |
| ``patch.yml`` | all | ``apt dist-upgrade``, one host at a time, rebooting if needed. |
| ``monitoring.yml`` | all | node_exporter. |
| ``fail2ban.yml`` | all | fail2ban with an sshd jail. |
| ``mgmt.yml`` | mgmt | tools-bin dependencies, copies the talosconfigs Terraform wrote to ``~/.talos/contexts`` and runs ``context-setup k8s``. |

Rebuilt VMs (by Terraform or by hand) have new SSH host keys. Run ``./build.sh <root> --refresh-keys`` (or ``ansible-playbook readycheck.yml -e refresh_host_keys=true``) to remove the old keys from ``~/.ssh/known_hosts`` before connecting.

Playbooks can be re-run on their own from ``playbooks/``, e.g. ``ansible-playbook patch.yml``. ``context-setup`` is only re-run when a talosconfig changes or a cluster's kubeconfig is missing, use ``ansible-playbook mgmt.yml -e management_context_setup=true`` to renew the kubeconfig certificates.

## prx-999 (GitOps)

A standalone Proxmox node (not joined to the ``prx-00x`` cluster) for the servers that manage the clusters. The VMs are defined in ``terraform/gitops/servers.auto.tfvars``, named ``prx-999-srv-<role>-<number>``, and the role is the VM's Ansible group (``vault``, ``git``, ``runner``). VMIDs count up from 900 and IPs from ``192.168.111.200``, management VMs count down from 999 and ``.254``. See ``docs/gitops-migration-plan.md`` for the overall plan.

### Host setup (manual)

Nothing is automated on the Proxmox host itself.

1. Install Proxmox VE: node name ``prx-999``, IP ``192.168.111.9/24``, gateway ``192.168.111.1``, bridge ``vmbr0``. Don't join it to the ``prx-00x`` cluster.
2. Disable the enterprise repositories, enable ``pve-no-subscription``, then ``apt update && apt full-upgrade``.
3. Keep the default storage: ``local`` (directory, needs the "ISO image" content type for the Debian image) and ``local-lvm`` (LVM-thin, VM disks).
4. Terraform uses ``root@pam`` with its password, the same as the clusters root (a scoped API token may replace it later).
5. Router DNS records (``/jffs/configs/dnsmasq.conf.add``, documented in ``HiredNoobs/documentation/network/router.md``), only the essential ones: ``vault.hirednoobs.com`` -> ``192.168.111.202``, added when Vault is cut over.

### Bootstrap secrets

prx-999 can't depend on Vault, so its own secrets are files on the Ansible controller in ``secrets/`` at the root of this repo (``bootstrap_secrets_dir``). The directory is git ignored, create it with ``mkdir -m 700 secrets`` and keep a backup of it outside the repo:

| File | Used for |
| --- | --- |
| ``cloudflare-api-token`` | certbot's DNS-01 challenge. A Cloudflare token with only Zone.DNS:Edit on ``hirednoobs.com``. |
| ``vault-keys.json`` | Vault's unseal keys and root token (``keys``, ``keys_base64``, ``root_token``). Keep a copy on the NAS and offline. |

### Vault

``prx-999-srv-vault-001`` runs a single Vault node with raft storage (``playbooks/roles/vault``), listening on 443 with a Let's Encrypt certificate (``playbooks/roles/certbot``) so clients use ``https://vault.hirednoobs.com`` as before. On the VM, ``vault`` talks to the local node (``/etc/profile.d/vault.sh``).

Vault starts sealed after every restart (reboot, ``patch.yml``, config or version change). Unseal it from ``playbooks/``:

```bash
ansible-playbook vault-unseal.yml
```

A new, empty Vault is initialised by hand on the VM, then unsealed with the playbook:

```bash
vault operator init -key-shares=4 -key-threshold=3 -format=json \
  | jq '{keys: .unseal_keys_hex, keys_base64: .unseal_keys_b64, root_token: .root_token}'
# Save the output as vault-keys.json in the bootstrap secrets.
```

#### Moving Vault from stack-vault

The data comes across as a raft snapshot, the existing unseal keys keep working.

1. Don't write to Vault until this is finished.
2. On ``prx-001-srv-mgmt-001`` (in stack-vault's deployment):

   ```bash
   VAULT_TOKEN=$(jq -r .root_token "$SECRETS/keys.json") vault operator raft snapshot save vault.snap
   ```

   Copy ``vault.snap`` to the new VM, and ``keys.json`` to the bootstrap secrets as ``vault-keys.json``.
3. On ``prx-999-srv-vault-001``, initialise with throwaway keys, restore, then unseal with the original keys:

   ```bash
   vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/init.json
   vault operator unseal "$(jq -r '.unseal_keys_b64[0]' /tmp/init.json)"
   VAULT_TOKEN=$(jq -r .root_token /tmp/init.json) vault operator raft snapshot restore -force vault.snap
   shred -u /tmp/init.json vault.snap
   ```

   ```bash
   ansible-playbook vault-unseal.yml   # from playbooks/ on the controller
   ```

4. Check it on the VM: ``vault login`` (userpass), ``vault secrets list`` (``lab/``, ``labv2/``), ``vault auth list`` (``userpass/``), ``vault operator raft list-peers`` (only this node), and compare a few ``labv2/`` secrets with the old Vault.
5. Cut over: add the router record, remove ``vault``, ``vault1``-``vault3`` from stack-pihole and the vault upstreams from stack-nginx and deploy both. From mgmt check ``vault status`` and ``secret-status``.
6. Monitoring: point stack-grafana's ``vault`` scrape job at ``vault.hirednoobs.com:443`` and add the prx-999 VMs' node_exporters.
7. Retire stack-vault: ``deployment clean`` (keeps the volume), and after a week ``deployment purge``. Remove the ``vault_core_vault`` label from ``terraform/clusters/clusters.auto.tfvars`` and archive the repo.

Until the purge, rolling back is pointing DNS back, restoring the Pi-hole and nginx entries and deploying stack-vault (anything written to the new Vault since is lost).

## Usage

Install Terraform (the exact ``required_version`` in ``terraform/*/versions.tf``) and Ansible:

```bash
sudo pacman -S terraform ansible
```

Set env vars, both roots use the root account of the Proxmox API they talk to (``prx-001`` for clusters, ``prx-999`` for gitops), set the password for the root being built:

```bash
export TF_VAR_pm_user="root@pam"
export TF_VAR_pm_password="password"
```

Build a root, this shows the plan and asks before applying it (one resource at a time, see upgrades), then runs that root's playbooks on its hosts:

```bash
./build.sh clusters
./build.sh gitops
```

Remove everything in a root:

```bash
./teardown.sh <clusters|gitops>
```

Or run Terraform directly from ``terraform/<root>/``, use ``-parallelism=1`` when applying. Provider versions come from the committed ``.terraform.lock.hcl``, update them with ``terraform init -upgrade`` then ``terraform providers lock -platform=linux_amd64`` after bumping a version.

The talosconfigs are also left on the Terraform host (``talosconfig_dir``), use them if the management VMs are down.

## Upgrades

- Talos: bump ``talos_version``, nodes are upgraded in place (one at a time with ``-parallelism=1``).
- Kubernetes: bump ``kubernetes_version``, this runs Talos's ``upgrade-k8s``.
- Don't change ``talos_contract``, it pins the machine config schema to the version the clusters were created with.

- Vault: bump ``vault_version`` and ``vault_sha256`` together (``playbooks/roles/vault/defaults/main.yml``), the restart seals it.

**The state contains the cluster secrets (CAs, keys).** Each root's state is git ignored, keep a backup - without it Terraform can no longer manage the clusters.
