# iac-homelab

Terraform and Ansible for the Talos Linux Kubernetes clusters, and the Debian management VMs that manage them, on the ``prx-00x`` Proxmox hosts.

Terraform and Ansible run from a host outside the clusters, the management VMs (``prx-<host>-srv-mgmt-<number>``) are the jumpboxes used day to day.

## Clusters

Clusters are defined in ``terraform/clusters.auto.tfvars``, keyed by the tools-bin context name (e.g. ``production.core``). Node names are ``prx-<host>-...-<control|worker>-<number>`` and the Proxmox node, role and labels come from the name, e.g. ``prx-002-srv-prod-core-worker-001`` is a worker created on ``prx-002`` with:

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

The management VMs are defined in ``terraform/management.auto.tfvars``. They're the jumpboxes with tools-bin, ``talosctl`` and ``kubectl`` set up for every cluster, they're in the ``mgmt`` Ansible group.

Names are ``prx-<host>-srv-mgmt-<number>`` (the Proxmox node comes from the name). VMIDs count down from the top of their Proxmox node's range and IPs from the top of the subnet, ``prx-001-srv-mgmt-001`` is 199 / ``192.168.111.254``, one on ``prx-002`` would be 299 / ``192.168.111.253``.

Terraform creates the VMs from the Debian 13 cloud image, cloud-init creates ``admin_user`` with the key from ``ssh_public_key_file``. Terraform also writes the Ansible inventory (``playbooks/inventory.generated.yml``), then ``build.sh`` runs the playbooks:

| Playbook | Hosts | Does |
| --- | --- | --- |
| ``readycheck.yml`` | all | Waits for SSH and cloud-init, optionally forgets old host keys first (see below). |
| ``movein.yml`` | all | qemu-guest-agent, locale, tools-bin (``movein.sh``, checked out at ``tools_bin_version``, then ``setup bash vim tmux``), SSH keys between the hosts, key-only sshd, passwordless login on the Proxmox consoles. |
| ``patch.yml`` | all | ``apt dist-upgrade``, one host at a time, rebooting if needed. |
| ``monitoring.yml`` | all | node_exporter. |
| ``fail2ban.yml`` | all | fail2ban with an sshd jail. |
| ``mgmt.yml`` | mgmt | tools-bin dependencies, copies the talosconfigs Terraform wrote to ``~/.talos/contexts`` and runs ``context-setup k8s``. |

Rebuilt VMs (by Terraform or by hand) have new SSH host keys. Run ``./build.sh --refresh-keys`` (or ``ansible-playbook readycheck.yml -e refresh_host_keys=true``) to remove the old keys from ``~/.ssh/known_hosts`` before connecting.

Playbooks can be re-run on their own from ``playbooks/``, e.g. ``ansible-playbook patch.yml``. ``context-setup`` is only re-run when a talosconfig changes or a cluster's kubeconfig is missing, use ``ansible-playbook mgmt.yml -e management_context_setup=true`` to renew the kubeconfig certificates.

## Usage

Install Terraform (1.11+) and Ansible:

```bash
sudo pacman -S terraform ansible
```

Set env vars:

```bash
export TF_VAR_pm_user="root@pam"
export TF_VAR_pm_password="password"
```

Build, this shows the plan and asks before applying it (one resource at a time, see upgrades):

```bash
./build.sh
```

Remove everything:

```bash
./teardown.sh
```

Or run Terraform directly from ``terraform/``, use ``-parallelism=1`` when applying.

The talosconfigs are also left on the Terraform host (``talosconfig_dir``), use them if the management VMs are down.

## Upgrades

- Talos: bump ``talos_version``, nodes are upgraded in place (one at a time with ``-parallelism=1``).
- Kubernetes: bump ``kubernetes_version``, this runs Talos's ``upgrade-k8s``.
- Don't change ``talos_contract``, it pins the machine config schema to the version the clusters were created with.

**The state contains the cluster secrets (CAs, keys).** It is git ignored, keep a backup - without it Terraform can no longer manage the clusters.
