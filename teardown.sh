#!/usr/bin/env bash

THIS=$(realpath "$0")
HERE=$(dirname "$THIS")

# shellcheck source=state.sh
source "$HERE/state.sh"

case "$1" in
  clusters|gitops) ;;
  *)
    echo "Usage: $(basename "$0") <clusters|gitops>"
    exit 1
    ;;
esac

# The clusters root's state is in Postgres (state.sh).
if [[ "$1" == "clusters" ]]; then
  export_pg_conn_str || exit 1
fi

cd "$HERE/terraform/$1" || exit 1

terraform destroy
