terraform {
  # Exact, upgrades are deliberate. Kept in step with the other roots.
  required_version = "1.16.5"

  # In Postgres on the git VM (PG_CONN_STR, set by build.sh). Without it, from a copy on the NAS:
  # README, Terraform state.
  backend "pg" {
    schema_name = "vault"
  }

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.12.0"
    }
  }
}

# Logs in with VAULT_TOKEN, build.sh sets it to the root token from secrets/vault-keys.json. The
# provider talks to Vault when it's configured, so Vault has to be up and unsealed to plan.
provider "vault" {
  address = var.vault_address
}
