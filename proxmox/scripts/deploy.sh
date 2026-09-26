#!/usr/bin/env bash
# Turn a freshly booted skeleton VM into the NixOS machine from this flake.
#
#   scripts/deploy.sh <host> <address> <host-key-dir> <authorized-keys-file> [ssh-user]
#
#   host                  nixosConfigurations entry, e.g. dar-pve
#   address               the skeleton's IP (tofu output ipv4_address)
#   host-key-dir          holds ssh_host_ed25519_key{,.pub} from new-host-key.sh
#   authorized-keys-file  public key(s) allowed to log in as root afterwards
#   ssh-user              the skeleton's cloud-init user (default: debian);
#                         it needs passwordless sudo, which cloud-init gives it
#
# Environment: SSH_PORT (default 22), SSH_KEY (identity for the skeleton),
# KEXEC_TARBALL (see below), NIXOS_ANYWHERE_ARGS (extra flags, e.g.
# --ssh-option StrictHostKeyChecking=no for throwaway test VMs).
#
# By default the SKELETON downloads the NixOS kexec installer from GitHub
# releases. If it can't (no internet, or a TLS-intercepting proxy it doesn't
# trust), download the tarball where you run this and set KEXEC_TARBALL to
# its path: nixos-anywhere then uploads it over SSH instead.
#
# nixos-anywhere copies --extra-files into /mnt before running nixos-install,
# so the host key is already in place when sops-nix first decrypts secrets.
set -euo pipefail
cd "$(dirname "$0")/.."

host=${1:?host}; address=${2:?address}; keydir=${3:?host-key-dir}; authkeys=${4:?authorized-keys-file}
user=${5:-debian}

extra=$(mktemp -d)
trap 'rm -rf "$extra"' EXIT

install -d -m 755 "$extra/etc/ssh"
install -m 600 "$keydir/ssh_host_ed25519_key" "$extra/etc/ssh/ssh_host_ed25519_key"
install -m 644 "$keydir/ssh_host_ed25519_key.pub" "$extra/etc/ssh/ssh_host_ed25519_key.pub"
install -d -m 700 "$extra/root/.ssh"
install -m 600 "$authkeys" "$extra/root/.ssh/authorized_keys"

args=(--flake ".#$host" --extra-files "$extra" --ssh-port "${SSH_PORT:-22}" --target-host "$user@$address")
[[ -n "${SSH_KEY:-}" ]] && args+=(-i "$SSH_KEY")
[[ -n "${KEXEC_TARBALL:-}" ]] && args+=(--kexec "$KEXEC_TARBALL")
# shellcheck disable=SC2206 # intentional word splitting of extra flags
args+=(${NIXOS_ANYWHERE_ARGS:-})

nixos-anywhere "${args[@]}"
