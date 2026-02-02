#!/usr/bin/env bash
#
# This probably moves into tools-bin at somepoint...

set -euo pipefail

KEYFILE="${HOME}/.ssh/id_rsa"
PUBFILE="${KEYFILE}.pub"

mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

if [[ ! -f "$PUBFILE" ]]; then
    echo "No SSH keypair found. Generating a new one..."
    ssh-keygen -t rsa -b 4096 -f "$KEYFILE" -N ""
else
    echo "SSH keypair already exists: $PUBFILE"
fi
