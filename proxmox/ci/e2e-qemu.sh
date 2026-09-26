#!/usr/bin/env bash
# End to end, without Proxmox: the skeleton tofu/main.tf creates (Debian 13
# genericcloud image, UEFI, disk on virtio-scsi = /dev/sda, cloud-init user
# `debian` with an SSH key), booted in plain QEMU/KVM; then scripts/deploy.sh
# turns it into dar-pve; then the result is checked over SSH.
#
#   nix develop .#e2e -c ci/e2e-qemu.sh      (needs /dev/kvm)
#   E2E_ACCEL=tcg nix develop .#e2e -c ci/e2e-qemu.sh   (no KVM: very slow)
set -euo pipefail
cd "$(dirname "$0")/.."

work=$(mktemp -d)
cleanup() {
  [[ -f "$work/qemu.pid" ]] && kill "$(cat "$work/qemu.pid")" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
fail() {
  echo "FAIL: $*" >&2
  echo "--- last lines of the VM serial console ---" >&2
  tail -n 60 "$work/serial.log" >&2 || true
  exit 1
}
step() { echo "=== $* ($(date -u +%T))"; }

step "Download and verify the Debian cloud image"
base=https://cloud.debian.org/images/cloud/trixie/latest
img=debian-13-genericcloud-amd64.qcow2
curl -fsSL -o "$work/$img" "$base/$img"
curl -fsSL "$base/SHA512SUMS" | grep " $img\$" | (cd "$work" && sha512sum -c -)
qemu-img create -q -f qcow2 -b "$work/$img" -F qcow2 "$work/disk.qcow2" 20G

step "cloud-init seed: user debian, passwordless sudo, one SSH key"
ssh-keygen -q -t ed25519 -N "" -C e2e-deploy -f "$work/deploy"
cat > "$work/user-data" <<EOC
#cloud-config
users:
  - name: debian
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys: ["$(cat "$work/deploy.pub")"]
package_update: false
package_upgrade: false
EOC
printf 'instance-id: e2e\nlocal-hostname: skeleton\n' > "$work/meta-data"
genisoimage -quiet -output "$work/seed.iso" -volid cidata -joliet -rock "$work/user-data" "$work/meta-data"

step "Boot the skeleton"
install -m 644 "$OVMF_VARS" "$work/vars.fd"
if [[ "${E2E_ACCEL:-kvm}" == kvm ]]; then accel=(-enable-kvm -machine q35 -cpu host)
else accel=(-machine "q35,accel=tcg" -cpu max); fi
qemu-system-x86_64 "${accel[@]}" -smp 2 -m 2048 \
  -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
  -drive if=pflash,format=raw,file="$work/vars.fd" \
  -device virtio-scsi-pci,id=scsi0 \
  -drive file="$work/disk.qcow2",if=none,id=d0,format=qcow2,discard=unmap \
  -device scsi-hd,drive=d0,bus=scsi0.0 \
  -cdrom "$work/seed.iso" \
  -netdev user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22 -device virtio-net-pci,netdev=n0 \
  -device virtio-serial \
  -chardev socket,path="$work/qga.sock",server=on,wait=off,id=qga0 \
  -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
  -display none -serial file:"$work/serial.log" \
  -daemonize -pidfile "$work/qemu.pid"

ssh_opts=(-p 2222 -i "$work/deploy" -o ConnectTimeout=5 -o BatchMode=yes)
wait_ssh() { # user, known-hosts options...
  local user=$1; shift
  for _ in $(seq 1 90); do
    ssh "${ssh_opts[@]}" "$@" "$user@127.0.0.1" true 2>/dev/null && return 0
    sleep 5
  done
  return 1
}
wait_ssh debian -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  || fail "the skeleton never accepted SSH"
ssh "${ssh_opts[@]}" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  debian@127.0.0.1 'grep PRETTY_NAME /etc/os-release; lsblk -dno NAME,SIZE /dev/sda'

step "nixos-anywhere, through scripts/deploy.sh"
install -d -m 700 "$work/hostkey"
install -m 600 ci/test-host-key "$work/hostkey/ssh_host_ed25519_key"
install -m 644 ci/test-host-key.pub "$work/hostkey/ssh_host_ed25519_key.pub"
# E2E_KEXEC_LOCAL=1: fetch the kexec installer here and upload it, for runs
# where the VM can't reach GitHub itself (as behind an intercepting proxy).
if [[ -n "${E2E_KEXEC_LOCAL:-}" ]]; then
  curl -fsSL -o "$work/kexec.tar.gz" \
    https://github.com/nix-community/nixos-images/releases/download/nixos-25.05/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz
  export KEXEC_TARBALL="$work/kexec.tar.gz"
fi
SSH_PORT=2222 SSH_KEY="$work/deploy" \
NIXOS_ANYWHERE_ARGS="--ssh-option StrictHostKeyChecking=no --ssh-option UserKnownHostsFile=/dev/null" \
  scripts/deploy.sh dar-pve 127.0.0.1 "$work/hostkey" "$work/deploy.pub" \
  || fail "deploy.sh failed"

step "Wait for NixOS, trusting ONLY the pre-generated host key"
# Strict checking against the committed public key: this connects only if
# sshd on the new system serves the key deploy.sh injected.
echo "[127.0.0.1]:2222 $(cat ci/test-host-key.pub)" > "$work/known_hosts"
strict=(-o StrictHostKeyChecking=yes -o UserKnownHostsFile="$work/known_hosts")
wait_ssh root "${strict[@]}" || fail "NixOS never accepted SSH with the injected host key"
# Takes ONE string: ssh joins its arguments with spaces, so quoting inside
# separate arguments would be lost on the remote side.
# shellcheck disable=SC2029 # expanding on the client side is the point
on_vm() { ssh "${ssh_opts[@]}" "${strict[@]}" root@127.0.0.1 "$1"; }

step "Checks"
[[ "$(on_vm hostname)" == dar-pve ]] || fail "hostname"
echo "ok: hostname is dar-pve"
on_vm 'grep -q ^not-a-real-token- /run/secrets/demo-api-token' || fail "secret not decrypted"
[[ "$(on_vm "stat -c '%U %a' /run/secrets/demo-api-token")" == "demo 400" ]] || fail "secret ownership/mode"
echo "ok: sops-nix decrypted the secret with the injected host key (owner demo, mode 400)"
on_vm 'findmnt -no SOURCE,FSTYPE / | grep -q "sda2 ext4"' || fail "root filesystem"
on_vm 'test -f /boot/EFI/BOOT/BOOTX64.EFI' || fail "no fallback EFI loader"
echo "ok: disko layout on /dev/sda, booted through the fallback EFI loader"
on_vm 'systemctl is-active qemu-guest-agent' >/dev/null || fail "qemu-guest-agent not running"
reply=$(python3 - "$work/qga.sock" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); s.settimeout(10)
s.sendall(b'{"execute":"guest-get-host-name"}\n')
print(json.loads(s.recv(4096))["return"]["host-name"])
PY
)
[[ "$reply" == dar-pve ]] || fail "guest agent answered '$reply'"
echo "ok: the host reaches the guest agent over its virtio port ($reply)"
[[ "$(on_vm 'getent passwd demo' | cut -d: -f7)" == */zsh ]] || fail "demo's shell"
echo "ok: the base configuration came along (demo's login shell is zsh)"
step "All checks passed"
