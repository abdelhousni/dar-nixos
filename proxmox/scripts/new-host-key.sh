#!/usr/bin/env bash
# Create a host's SSH host key BEFORE its VM exists, and make it a sops
# recipient, so secrets can be encrypted to a machine that isn't born yet.
#
#   scripts/new-host-key.sh <out-dir> [secrets-file]
#
# Writes <out-dir>/ssh_host_ed25519_key{,.pub}. The private key is the host's
# identity and the key to its secrets: keep it OUT of the repo (a password
# manager, or OpenBao/Vault KV) and hand it to scripts/deploy.sh at install.
# Then adds the key's age recipient to .sops.yaml and re-encrypts the file
# (default secrets/demo.yaml). `sops updatekeys` must be able to decrypt the
# file, so run it with your admin age key (SOPS_AGE_KEY_FILE or the default
# ~/.config/sops/age/keys.txt).
set -euo pipefail
cd "$(dirname "$0")/.."

out=${1:?usage: new-host-key.sh <out-dir> [secrets-file]}
secrets=${2:-secrets/demo.yaml}

install -d -m 700 "$out"
[[ -e "$out/ssh_host_ed25519_key" ]] && { echo "$out/ssh_host_ed25519_key already exists" >&2; exit 1; }
ssh-keygen -q -t ed25519 -N "" -C "" -f "$out/ssh_host_ed25519_key"

recipient=$(ssh-to-age < "$out/ssh_host_ed25519_key.pub")
echo "age recipient: $recipient"

# Append the recipient to the creation rule that matches the secrets file.
export SECRETS=$secrets RECIPIENT=$recipient
# shellcheck disable=SC2016 # $r is a yq variable, not a shell one
rule=$(yq '.creation_rules | to_entries | map(select(.value.path_regex as $r | strenv(SECRETS) | test($r))) | .[0].key' .sops.yaml)
[[ "$rule" != "null" ]] || { echo "no creation_rule in .sops.yaml matches $secrets" >&2; exit 1; }
RULE=$rule yq -i '.creation_rules[env(RULE)].key_groups[0].age |= (. + [strenv(RECIPIENT)] | unique)' .sops.yaml

sops updatekeys --yes "$secrets"
echo "Re-encrypted $secrets. Commit .sops.yaml and $secrets; store $out/ssh_host_ed25519_key safely."
