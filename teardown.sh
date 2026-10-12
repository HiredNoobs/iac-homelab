#!/usr/bin/env bash

THIS=$(realpath "$0")
HERE=$(dirname "$THIS")

case "$1" in
  clusters|gitops) ;;
  *)
    echo "Usage: $(basename "$0") <clusters|gitops>"
    exit 1
    ;;
esac

# The clusters root's state is in Postgres, see build.sh.
if [[ "$1" == "clusters" && -z "${PG_CONN_STR:-}" ]]; then
  PG_CONN_STR="postgres://terraform:$(cat "$HERE/secrets/postgres-password")@git.hirednoobs.com/terraform?sslmode=verify-full" || exit 1
  export PG_CONN_STR
fi

cd "$HERE/terraform/$1" || exit 1

terraform destroy
