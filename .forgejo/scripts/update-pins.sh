#!/usr/bin/env bash
#
# Renovate's postUpgradeTask (renovate.json, allowed by the global config in the renovate repo's
# workflow), run in each branch after its version bumps: sets the checksum of each
# pinned download whose version changed, from the checksums upstream publishes with the release.
# Signatures aren't checked (the comments by each pin say how), do that when reviewing the PR.
#
# Only pins whose version changed in the branch are touched: an unchanged version keeps its
# committed checksum.
#
# Usage (from anywhere in the repo, after editing versions, uncommitted):
# bash .forgejo/scripts/update-pins.sh

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# file, version key, checksum key, published checksums URL ({v} is the version), the file's name
# in it ({v} too). An empty name means the URL is the checksum alone.
PINS=(
  ".forgejo/workflows/lint.yml TERRAFORM_VERSION TERRAFORM_SHA256 https://releases.hashicorp.com/terraform/{v}/terraform_{v}_SHA256SUMS terraform_{v}_linux_amd64.zip"
  "playbooks/roles/vault/defaults/main.yml vault_version vault_sha256 https://releases.hashicorp.com/vault/{v}/vault_{v}_SHA256SUMS vault_{v}_linux_amd64.zip"
  "playbooks/roles/monitoring/defaults/main.yml node_exporter_version node_exporter_sha256 https://github.com/prometheus/node_exporter/releases/download/v{v}/sha256sums.txt node_exporter-{v}.linux-amd64.tar.gz"
  "playbooks/roles/forgejo/defaults/main.yml forgejo_version forgejo_sha256 https://codeberg.org/forgejo/forgejo/releases/download/v{v}/forgejo-{v}-linux-amd64.sha256"
  "playbooks/roles/forgejo_runner/defaults/main.yml forgejo_runner_version forgejo_runner_sha256 https://code.forgejo.org/forgejo/runner/releases/download/v{v}/forgejo-runner-{v}-linux-amd64.sha256"
)

# Galaxy publishes the collection's checksum in its version's metadata.
GALAXY_PINS=(
  ".forgejo/workflows/lint.yml ANSIBLE_POSIX_VERSION ANSIBLE_POSIX_SHA256 ansible posix"
)

function log {
  echo "update-pins: $*" >&2
}

# The quoted value of `<key>: "<value>"` in YAML on stdin.
function yaml_value {
  sed -nE "s/^ *$1: \"([^\"]*)\".*/\1/p" | head -n1
}

# Prints the new version if it changed in this branch, fails otherwise.
function changed_version {
  local file=$1 key=$2 new old
  new=$(yaml_value "$key" < "$file")
  old=$(git show "HEAD:$file" | yaml_value "$key")
  [[ -n $new && $new != "$old" ]] && echo "$new"
}

function set_checksum {
  local file=$1 key=$2 sum=$3
  if [[ ! $sum =~ ^[0-9a-f]{64}$ ]]; then
    log "$key: no checksum found"
    return 1
  fi
  sed -i -E "s/^( *$key: )\"[0-9a-f]*\"/\1\"$sum\"/" "$file"
  log "$key: $sum"
}

for pin in "${PINS[@]}"; do
  read -r file version_key sum_key url name <<< "$pin"
  version=$(changed_version "$file" "$version_key") || continue

  url=${url//\{v\}/$version}
  name=${name//\{v\}/$version}
  log "$version_key $version: reading $url"
  sums=$(curl -fsSL "$url")
  if [[ -n $name ]]; then
    sum=$(awk -v name="$name" '$2 == name || $2 == "*" name { print $1 }' <<< "$sums")
  else
    sum=$(awk '{ print $1; exit }' <<< "$sums")
  fi
  set_checksum "$file" "$sum_key" "$sum"
done

for pin in "${GALAXY_PINS[@]}"; do
  read -r file version_key sum_key namespace collection <<< "$pin"
  version=$(changed_version "$file" "$version_key") || continue

  url="https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/index/$namespace/$collection/versions/$version/"
  log "$version_key $version: reading $url"
  sum=$(curl -fsSL "$url" | grep -oE '"sha256": *"[0-9a-f]{64}"' | head -n1 | grep -oE '[0-9a-f]{64}')
  set_checksum "$file" "$sum_key" "$sum"
done
