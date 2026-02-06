#!/usr/bin/env bash

THIS=$(realpath "$0")
HERE=$(dirname "$THIS")

cd "$HERE/terraform" || exit 1

terraform destroy
