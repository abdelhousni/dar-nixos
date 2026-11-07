# Handover: feat/wsl-ghostty

Work in progress, to continue on the WSL NixOS box. **Delete this file before merging.**

## What's on the branch

1. `feat: install Ghostty's terminfo on the machine`: `pkgs.ghostty.terminfo` in `configuration.nix`, an `infocmp xterm-ghostty` check in `test.nix`, and a README line.
2. `feat: wsl/, ...`: a new flake in [`wsl/`](wsl). NixOS-WSL `release-26.05` plus [`wsl/host.nix`](wsl/host.nix), which imports `../configuration.nix` and adds:
   - the hostname `dar-wsl`, with `demo` as the default user
   - `useWindowsDriver` and `startMenuLaunchers`
   - systemd-boot and sshd forced off
   - the full `pkgs.ghostty`
   - channels off and flakes on

   It also adds [`.github/workflows/wsl.yml`](.github/workflows/wsl.yml), which builds the file on Ubuntu and checks it in WSL2 on `windows-latest`, plus [`wsl/ci/checks.sh`](wsl/ci/checks.sh), `.gitattributes` (`*.sh` stays LF) and docs.

## Not verified yet

The machine this was written on had no Nix, no KVM and no podman, so:

- Neither `configuration.nix` nor `wsl/` has been evaluated or built.
- `wsl/flake.lock` doesn't exist yet.
- No CI run has seen either commit.

## Next steps

```sh
git fetch origin && git switch feat/wsl-ghostty

# 1. Lock the WSL flake and commit the lock file.
cd wsl
nix --extra-experimental-features 'nix-command flakes' flake lock
git add flake.lock && git commit -m "chore: lock wsl/ flake inputs"

# 2. Evaluate and build what CI builds.
nix build .#nixosConfigurations.dar-wsl.config.system.build.toplevel
cd .. && NIX_PATH=nixpkgs=channel:nixos-26.05 ./ci/eval-checks.sh

# 3. Build the distribution file, then on Windows:
#    wsl --install --from-file dar-wsl.wsl --name dar-wsl
#    wsl -d dar-wsl --cd <checkout> -- bash wsl/ci/checks.sh
#    and start `ghostty` to check that WSLg draws a window.
cd wsl && sudo nix --extra-experimental-features 'nix-command flakes' run .#tarballBuilder -- dar-wsl.wsl
```

Then push, open the pull request, and delete this file.

## Expected rough edges

- **`systemctl is-system-running` in `checks.sh`** may report `degraded` because of WSL-specific units. If so, look at `systemctl --failed` before loosening the check.
- **`ghostty +version` without a display** is assumed to work, as CLI actions shouldn't initialise GTK. Unconfirmed.
- **`nix.channel.enable = false`** is assumed to give `nix-shell -p` a working `NIX_PATH` from the flake's nixpkgs. Check it on the box.
- **The Start menu entry** is expected to be named "Ghostty (dar-wsl)", as WSLg usually names them. Unconfirmed.

## For the pull request

- Title: Conventional Commits, e.g. `feat: WSL2 distribution with Ghostty, and Ghostty terminfo on the base machine`, or split it into two PRs.
- Say why NixOS-WSL departs from "stay vanilla" (`CLAUDE.md`): it's a nix-community project, not nixpkgs, but stock NixOS has no WSL support.
- No TIL entry links to `wsl/` yet, so no entry needs updating.
