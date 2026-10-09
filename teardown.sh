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

cd "$HERE/terraform/$1" || exit 1

terraform destroy
