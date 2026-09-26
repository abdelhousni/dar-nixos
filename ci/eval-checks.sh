#!/usr/bin/env bash
# Evaluation-only checks: nothing is built and no VM boots, so this needs
# neither KVM nor root. It runs anywhere Nix runs (any CI runner, any laptop)
# in well under a minute once nixpkgs is downloaded.
#
#   NIX_PATH=nixpkgs=channel:nixos-26.05 ./ci/eval-checks.sh
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $*" >&2; exit 1; }

# 1. The whole system evaluates. This is where NixOS assertions fire, e.g.
#    "users.users.<name>.shell is set to zsh, but programs.zsh.enable is not true".
#    The VM variant is used because the repo has no hardware-configuration.nix
#    (no root filesystem), which the real `system` attribute asserts on.
nix-instantiate '<nixpkgs/nixos>' -A vm -I nixos-config=./configuration.nix >/dev/null
echo "ok: system evaluates, all assertions pass"

# 2. Read the /etc/zshrc NixOS would generate, as plain text.
zshrc=$(nix-instantiate --eval --strict --raw -E \
  '(import <nixpkgs/nixos> { configuration = ./configuration.nix; }).config.environment.etc.zshrc.text')

# Oh My Zsh calls compinit itself, so NixOS must not (enableGlobalCompInit = false).
if grep -q 'autoload -U compinit' <<<"$zshrc"; then
  fail "/etc/zshrc runs compinit before Oh My Zsh does (set programs.zsh.enableGlobalCompInit = false)"
fi
echo "ok: compinit is left to Oh My Zsh"

# An empty theme means no Oh My Zsh prompt at all.
grep -q '^ZSH_THEME="..*"' <<<"$zshrc" || fail "no Oh My Zsh theme set"
echo "ok: a theme is set"

# NixOS aliases come after Oh My Zsh, so they override plugin aliases of the
# same name. Make that ordering, and the one intended override, explicit.
omz=$(grep -n 'source $ZSH/oh-my-zsh.sh' <<<"$zshrc" | cut -d: -f1)
gc=$(grep -n "^alias -- gc=" <<<"$zshrc" | cut -d: -f1)
[[ -n "$omz" && -n "$gc" ]] || fail "expected both the Oh My Zsh source line and a gc alias"
(( gc > omz )) || fail "the gc alias is set before Oh My Zsh loads, so the git plugin would win"
echo "ok: the NixOS gc alias (line $gc) comes after Oh My Zsh (line $omz)"
