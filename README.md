# dar-nixos

A deliberately small NixOS machine, described in one file. It's the companion repo for these TIL entries:

- [First steps on NixOS: the whole system is one file, and every change is a boot entry](https://abdelhousni.github.io/til/nixos/first-steps-configuration-generations-rollback.html)
- [Oh My Zsh on NixOS: the plugin list installs nothing, and NixOS aliases win](https://abdelhousni.github.io/til/nixos/zsh-oh-my-zsh-declarative.html)
- [Home Manager as a NixOS module: dotfiles in the same rebuild, and the file that's in the way](https://abdelhousni.github.io/til/nixos/home-manager-nixos-module.html)
- [Testing a NixOS configuration on GitHub Actions](https://abdelhousni.github.io/til/nixos/nixos-config-tests-github-actions.html) and [on self-managed GitLab CE](https://abdelhousni.github.io/til/nixos/nixos-config-tests-gitlab-ce.html)

| File | What it is |
|---|---|
| [`configuration.nix`](configuration.nix) | The whole machine: hostname, packages, SSH, a user, weekly garbage collection, `stateVersion`. Commented line by line. |
| [`zsh.nix`](zsh.nix) | Zsh with Oh My Zsh, imported by `configuration.nix`. |
| [`home.nix`](home.nix) | Home Manager as a NixOS module: the `demo` user's git config, a package and a dotfile, activated by `nixos-rebuild`. Imported by `configuration.nix`. |
| [`ci/eval-checks.sh`](ci/eval-checks.sh) | Evaluation-only checks: builds nothing, needs no KVM. |
| [`test.nix`](test.nix) | A NixOS VM test that boots `configuration.nix` and checks what the TILs claim about it. |
| [`.github/workflows/check.yml`](.github/workflows/check.yml) | Runs both on GitHub Actions, on every push. |
| [`.gitlab-ci.yml`](.gitlab-ci.yml) | The same two jobs for a self-managed GitLab CE runner. |
| [`.github/workflows/security.yml`](.github/workflows/security.yml) | gitleaks over the whole Git history, and actionlint + zizmor over the workflows. On every push and weekly. |
| [`.gitleaks.toml`](.gitleaks.toml) | gitleaks' default rules, with a single allowlisted file: a CI-only test key. |
| [`proxmox/`](proxmox) | The same machine on Proxmox: OpenTofu creates a skeleton VM, nixos-anywhere installs NixOS from a flake, sops-nix brings the secrets. A flake of its own; see its README. |

It targets **NixOS 26.05** and uses plain `configuration.nix` with channels, not flakes, to match the TIL.

## Try it without installing NixOS

On any Linux machine with [Nix](https://nixos.org/download/) installed:

```sh
nix-build '<nixpkgs/nixos>' -A vm \
  -I nixpkgs=channel:nixos-26.05 \
  -I nixos-config=./configuration.nix
./result/bin/run-dar-nixos-vm
```

The script is named after `networking.hostName`. Log in at the VM console as `demo` / `demo`. That password is set only inside `virtualisation.vmVariant`, so it never exists on a real install.

SSH on the host's port 2222 is forwarded to the VM, but password login is disabled on purpose. To use it, add your public key to `users.users.demo.openssh.authorizedKeys.keys` first.

## Run the checks

Two levels. The first needs only Nix:

```sh
NIX_PATH=nixpkgs=channel:nixos-26.05 ./ci/eval-checks.sh
```

It evaluates the whole system (so NixOS assertions fire) and inspects the generated `/etc/zshrc`: no second `compinit`, a theme set, and the NixOS `gc` alias written after Oh My Zsh. For `home.nix`, it fails if Home Manager and nixpkgs are on different releases (Home Manager itself only warns) and checks the generated git config.

The second boots the machine in QEMU and needs KVM:

```sh
nix-build test.nix -I nixpkgs=channel:nixos-26.05
```

It asserts that sshd is running on port 22, `git` and `htop` are on the PATH, the hostname is set, the `nix-gc` timer exists, the running system is a Nix store path, and, for `zsh.nix`, that zsh is the login shell, `gc` is the NixOS alias, no Oh My Zsh plugin warns at startup, and `compinit` ran once. For `home.nix`, it checks that the `home-manager-demo` unit ran before logins were allowed, that managed files are store symlinks, that `rg` comes from `/etc/profiles/per-user/demo`, and that a file in the way of a managed one is backed up once, then blocks activation. The test sets `qemu.forceAccel = true`, so without usable KVM it fails with a clear message instead of crawling along in software emulation.

To poke at the VM from a Python REPL instead:

```sh
$(nix-build test.nix -A driverInteractive -I nixpkgs=channel:nixos-26.05)/bin/nixos-test-driver
```

## Use it on a real NixOS machine

Only do this on a test machine. It replaces your configuration.

1. **Add your SSH public key** to `users.users.demo.openssh.authorizedKeys.keys`. Password login over SSH is disabled, so without a key you'll lose remote access after switching.
2. Copy the file in next to the `hardware-configuration.nix` the installer generated. `configuration.nix` imports that file automatically when it exists.

   ```sh
   sudo cp configuration.nix zsh.nix home.nix /etc/nixos/
   ```
3. Apply it without making it the boot default. If anything goes wrong, rebooting undoes it:

   ```sh
   sudo nixos-rebuild test
   ```
4. Once it's good, make it permanent:

   ```sh
   sudo nixos-rebuild switch
   ```
5. Go back to the previous generation:

   ```sh
   sudo nixos-rebuild switch --rollback
   ```

**Keep your installer's `system.stateVersion`.** If your machine was installed with an older release, change the value in this file to match what your original config had, rather than the other way round. The TIL explains why.

## Not here on purpose

At the root, flakes, secrets and multiple hosts are left out. Each one is worth learning, but only after the basic loop is familiar: edit, rebuild, and roll back. [`proxmox/`](proxmox) is the next step: it adds a flake and secrets on top of the same configuration.
