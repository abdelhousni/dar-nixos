#!/usr/bin/env bash
# Runs inside the imported distribution, as its default user, on a Windows
# runner with real WSL2:
#
#   wsl -d dar-wsl --cd <checkout> -- bash wsl/ci/checks.sh
#
# The base machine is covered by ../../test.nix; this checks what WSL changes.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

# wsl.conf turns systemd on, and the first boot ends with no failed units.
state=$(systemctl is-system-running --wait || true)
if [[ $state != running ]]; then
  systemctl --failed --no-pager >&2 || true
  fail "systemd is '$state', not 'running'"
fi
echo "ok: systemd is running, no failed units"

# wsl.defaultUser: the base machine's user, with the login shell from zsh.nix.
[[ $(id -un) == demo ]] || fail "logged in as $(id -un), not demo"
getent passwd demo | grep -q '/bin/zsh$' || fail "demo's login shell isn't zsh"
echo "ok: logged in as demo, zsh is the login shell"

# WSL sets the hostname from wsl.conf, which NixOS-WSL fills in from
# networking.hostName.
host=$(cat /proc/sys/kernel/hostname)
[[ $host == dar-wsl ]] || fail "hostname is $host, not dar-wsl"
echo "ok: hostname is dar-wsl"

# Packages from configuration.nix, home.nix and host.nix.
for cmd in git htop rg ghostty; do
  command -v "$cmd" >/dev/null || fail "$cmd isn't on the PATH"
done
infocmp xterm-ghostty >/dev/null || fail "no xterm-ghostty terminfo entry"
echo "ok: git, htop, rg and $(ghostty +version | head -n 1) are installed, with Ghostty's terminfo"

# Home Manager activated at boot, as on the base machine.
systemctl is-active --quiet home-manager-demo.service || fail "home-manager-demo.service isn't active"
readlink -f "$HOME/.config/git/config" | grep -q '^/nix/store/' || fail "$HOME/.config/git/config isn't managed by Home Manager"
echo "ok: Home Manager activated the demo user's files"

# host.nix turns sshd off: the way in is `wsl -d`.
if systemctl is-active --quiet sshd.service; then
  fail "sshd is running"
fi
echo "ok: sshd is off"

# startMenuLaunchers copied Ghostty's .desktop file to where WSLg looks.
compgen -G '/usr/share/applications/*ghostty*.desktop' >/dev/null \
  || fail "no Ghostty .desktop file in /usr/share/applications"
echo "ok: Ghostty has a Start menu entry for WSLg"

# useWindowsDriver: Mesa can load the Windows GPU driver that WSL mounts at
# /usr/lib/wsl/lib. The links exist even where the runner has no GPU.
[[ -L /run/opengl-driver/lib/libd3d12.so ]] || fail "the Windows d3d12 driver isn't linked into /run/opengl-driver"
echo "ok: the Windows GPU driver is linked for Mesa"

# Whether WSLg draws a window can't be checked here (a CI runner has no
# desktop session to look at). Print what this runner offers, for the log.
echo "info: DISPLAY=${DISPLAY:-unset} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}"
find /mnt/wslg -maxdepth 1 -mindepth 1 -printf 'info: %p\n' 2>/dev/null || true
