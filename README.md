# dar-nixos

A deliberately small NixOS machine, described in one file. It's the companion repo for the TIL [First steps on NixOS: the whole system is one file, and every change is a boot entry](https://abdelhousni.github.io/til/nixos/first-steps-configuration-generations-rollback.html).

| File | What it is |
|---|---|
| [`configuration.nix`](configuration.nix) | The whole machine: hostname, packages, SSH, a user, weekly garbage collection, `stateVersion`. Commented line by line. |
| [`test.nix`](test.nix) | A NixOS VM test that boots `configuration.nix` and checks what the TIL claims about it. |
| [`.github/workflows/check.yml`](.github/workflows/check.yml) | Runs that test on every push. |

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

```sh
nix-build test.nix -I nixpkgs=channel:nixos-26.05
```

This boots the machine in QEMU and asserts that sshd is running on port 22, `git` and `htop` are on the PATH, the hostname is set, the `nix-gc` timer exists, and the running system is a Nix store path. It's fast with KVM and works slowly without it.

To poke at the VM from a Python REPL instead:

```sh
$(nix-build test.nix -A driverInteractive -I nixpkgs=channel:nixos-26.05)/bin/nixos-test-driver
```

## Use it on a real NixOS machine

Only do this on a test machine. It replaces your configuration.

1. **Add your SSH public key** to `users.users.demo.openssh.authorizedKeys.keys`. Password login over SSH is disabled, so without a key you'll lose remote access after switching.
2. Copy the file in next to the `hardware-configuration.nix` the installer generated. `configuration.nix` imports that file automatically when it exists.

   ```sh
   sudo cp configuration.nix /etc/nixos/configuration.nix
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

Flakes, home-manager, secrets and multiple hosts are left out. Each one is worth learning, but only after the basic loop is familiar: edit, rebuild, and roll back.
