# Created by stack-vault's initial-setup before Vault was managed here, and restored with its
# data. Delete this file once they're imported (the first apply): on a new, empty Vault there's
# nothing to import and the plan fails.
import {
  to = vault_mount.lab
  id = "lab"
}

import {
  to = vault_mount.labv2
  id = "labv2"
}

import {
  to = vault_auth_backend.userpass
  id = "userpass"
}

import {
  to = vault_policy.lab
  id = "lab-policy"
}

import {
  to = vault_policy.labv2
  id = "labv2-policy"
}
