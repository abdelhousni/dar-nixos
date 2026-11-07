# dar-nixos on WSL2: the same machine on Windows, with Ghostty on the desktop

The dar-nixos machine from [`../configuration.nix`](../configuration.nix) as a WSL2 distribution, built with [NixOS-WSL](https://github.com/nix-community/NixOS-WSL). WSLg draws Linux GUI apps on the Windows desktop, so this one installs the whole [Ghostty](https://ghostty.org/) terminal, not only its terminfo.

[`host.nix`](host.nix) holds only what differs from the base machine:

- **NixOS-WSL**, with `demo` as the user `wsl -d` logs in as, the Windows GPU driver handed to Mesa (`useWindowsDriver`), and Start menu entries for GUI apps (`startMenuLaunchers`).
- **No bootloader.** WSL starts its own kernel, so the systemd-boot that `configuration.nix` enables is forced off.
- **No sshd.** You get in with `wsl -d`, and in WSL's mirrored networking mode sshd would listen on the Windows host's network.
- **No channels, flakes on.** The system comes from this flake and is rebuilt from it. A plain `nixos-rebuild switch` fails rather than rebuilding from the starter `/etc/nixos/configuration.nix` that NixOS-WSL writes, which would replace this machine with a bare NixOS-WSL.
- **No password.** NixOS-WSL lets `wheel` use sudo without one, and `demo` has none. The boundary is your Windows account.

This directory is a flake of its own, like [`../proxmox`](../proxmox), so the repo root keeps its channel-based setup. NixOS-WSL isn't part of nixpkgs: it's the nix-community project for running NixOS under WSL, and stock NixOS has no WSL support to use instead.

**Status:** CI builds the distribution and boots it in real WSL2 on a Windows runner. A Ghostty window drawn by WSLg can't be checked there, so that part is checked by hand.

## Prerequisites

- **Windows 10 or 11 with WSL 2 from the Microsoft Store**, which includes WSLg: `wsl --install --no-distribution`, then `wsl --update`. `wsl --version` should list a WSLg version.
- **Nix with flakes on Linux** to build the file. Another WSL distribution works.

## Run it

```sh
# 1. Build dar-wsl.wsl. The builder runs nixos-install, so it needs root.
cd wsl
sudo nix run .#tarballBuilder -- dar-wsl.wsl
```

```powershell
# 2. Import it on Windows, then start it. The first start boots systemd and
#    activates Home Manager, so it takes a moment.
wsl --install --from-file dar-wsl.wsl --name dar-wsl
wsl -d dar-wsl
```

On WSL older than 2.4.4, import with `wsl --import dar-wsl $env:USERPROFILE\dar-wsl dar-wsl.wsl --version 2` instead.

```sh
# 3. Ghostty, drawn by WSLg. It also appears in the Start menu as
#    "Ghostty (dar-wsl)".
ghostty &

# 4. Later changes: rebuild from a checkout inside the distribution.
git clone https://github.com/abdelhousni/dar-nixos.git && cd dar-nixos/wsl
sudo nixos-rebuild switch --flake .#dar-wsl
```

To start over: `wsl --unregister dar-wsl` deletes the distribution and its disk.

## Checks

| What | How | Needs |
|---|---|---|
| The distribution file builds | `tarball` job: `sudo nix run .#tarballBuilder` | root, no KVM |
| It boots in WSL2 and keeps the base machine's promises | `wsl` job: [`ci/checks.sh`](ci/checks.sh) inside the imported distribution | Windows with WSL2 |
| Ghostty opens a window | by hand: `ghostty` in `wsl -d dar-wsl` | WSLg |

`ci/checks.sh` checks that systemd boots with no failed units, that `demo` is the login user with zsh, and that the hostname is `dar-wsl`. It checks that `git`, `htop`, `rg` and `ghostty` are installed with Ghostty's terminfo, that Home Manager activated, that sshd is off, that Ghostty's `.desktop` file is where WSLg looks for Start menu entries, and that the Windows d3d12 driver is linked for Mesa.

The base machine's VM test, [`../test.nix`](../test.nix), doesn't cover this flake: WSL replaces the kernel, bootloader and init that the test VM boots.
