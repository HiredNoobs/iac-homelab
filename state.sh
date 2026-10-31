# shellcheck shell=bash
#
# Sourced by build.sh and teardown.sh. The clusters and vault roots keep their Terraform state in
# Postgres on the git VM (terraform-state.yml), as this database role unless PG_CONN_STR is
# already set.
STATE_HOST=git.hirednoobs.com
STATE_DATABASE=terraform
STATE_ROLE=terraform

# Exports PG_CONN_STR for the Postgres backend, with the role's password from secrets/.
function export_pg_conn_str {
  [[ -n "${PG_CONN_STR:-}" ]] && return 0
  local password
  password=$(cat "$(dirname "${BASH_SOURCE[0]}")/secrets/postgres-password") || return 1
  export PG_CONN_STR="postgres://$STATE_ROLE:$password@$STATE_HOST/$STATE_DATABASE?sslmode=verify-full"
}
