# Backups

Data, not VMs: the VMs are rebuilt by Terraform and Ansible. ``backups.yml`` (``build.sh gitops`` runs it) sets up a nightly backup on each VM, to a NAS share of its own whose user can only reach that share. A failed backup fails its service (``HostSystemdServiceCrashed`` alerts), ``journalctl -u <service>`` shows each run.

| What | Service | NAS share | Kept |
| --- | --- | --- | --- |
| Vault: a Raft snapshot, 03:15 | ``vault-backup`` on the vault VM | ``vault-backups``: ``<UTC time>.snap`` | The newest 14, older ones for 90 days. |
| Forgejo: a dump of its database, ``/var/lib/forgejo``, ``/etc/forgejo`` (with the generated secrets), 03:30 | ``forgejo-backup`` on the git VM | ``forgejo-backups``: a restic repository in ``restic/`` | 14 daily, 8 weekly, 12 monthly. |
| Terraform state | See [Terraform state](terraform-state.md). | ``terraform-state`` | |

- **Vault's snapshots need ``keys.json`` to be read, Forgejo's repository needs ``secrets/restic-forgejo``.** Neither is on the VMs' shares: keep both (all of ``secrets/``) on the NAS somewhere the VMs can't reach, and an offline copy.
- Vault's backup logs in with the AppRole ``vault-backup`` (``terraform/vault``), whose token can only take a snapshot and revoke itself, and whose secret ID and tokens only work from the VM (127.0.0.1). ``backups.yml`` creates the secret ID from the controller with the root token (``VaultRootTokenUsed`` and ``VaultConfigChange`` alert, as they should), only when the VM has none: ``-e vault_backup_new_secret_id=true`` replaces it and destroys the old one. Vault must be unsealed and ``terraform/vault`` applied for that, ``backups.yml`` says when it isn't.
- Forgejo's backup runs as ``forgejo-backup``, which reads every file (``CAP_DAC_READ_SEARCH``) and the database (``pg_read_all_data``) but can't write to Forgejo, and Forgejo (``git``) can't read or delete the backups.

## Setting up the backups

1. On the NAS (by hand): shares ``vault-backups`` and ``forgejo-backups``, users ``vault-backups`` and ``forgejo-backups`` with read/write on their own share only. Their passwords go in ``secrets/nas-vault-backups`` and ``secrets/nas-forgejo-backups`` (no special characters, they're mount options).
2. ``openssl rand -hex 32 > secrets/restic-forgejo``, then copy it off the machine running Ansible (see above).
3. ``./build.sh vault`` (the AppRole), then ``ansible-playbook backups.yml`` from ``playbooks/`` (``build.sh gitops`` runs it too).
4. Check a run on each VM: ``sudo systemctl start vault-backup`` / ``forgejo-backup``, then ``journalctl -u`` it.

## Restoring Vault

On a new, empty Vault (``vault.yml`` run, not initialised), with a snapshot copied to the VM:

```bash
vault operator init -key-shares=1 -key-threshold=1 -format=json > /tmp/init.json
vault operator unseal "$(jq -r '.unseal_keys_b64[0]' /tmp/init.json)"
VAULT_TOKEN=$(jq -r .root_token /tmp/init.json) vault operator raft snapshot restore -force <snapshot>.snap
shred -u /tmp/init.json <snapshot>.snap
```

From then on it's the snapshot's Vault: ``keys.json``'s keys and root token, the temporary ones are gone. After the next restart unseal it with ``vault-unseal.yml``. Then ``ansible-playbook backups.yml``, which creates a secret ID if the VM has none; if the next backup's login is refused (the snapshot is older than the VM's secret ID), add ``-e vault_backup_new_secret_id=true``.

## Restoring Forgejo

On the git VM after ``forgejo.yml``, as root, with ``RESTIC_REPOSITORY=/mnt/forgejo-backups/restic`` and ``RESTIC_PASSWORD_FILE=/etc/forgejo-backup/restic-password`` (``backups.yml`` sets both up; ``restic snapshots`` lists them):

```bash
systemctl stop forgejo
restic restore latest --target /restore
rsync -a --delete /restore/var/lib/forgejo/ /var/lib/forgejo/
rsync -a --delete /restore/etc/forgejo/secrets/ /etc/forgejo/secrets/
sudo -u postgres dropdb forgejo
sudo -u postgres createdb --owner git --encoding UTF8 --locale C.UTF-8 --template template0 forgejo
sudo -u postgres psql -X -q -v ON_ERROR_STOP=1 -d forgejo < /restore/var/lib/forgejo-backup/forgejo.sql
systemctl start forgejo
sudo -u git forgejo --config /etc/forgejo/app.ini --work-path /var/lib/forgejo doctor check --all
```

``app.ini`` comes from Ansible, the restored copy is only for comparing. Search indexes and queues aren't backed up, Forgejo rebuilds them. Restore the Terraform state database too if the VM was rebuilt (see [Break-glass](terraform-state.md#break-glass)).
