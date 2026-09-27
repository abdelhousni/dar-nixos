# dar-nixos on Proxmox: provisioned on demand, installed from Git, secrets included

The dar-nixos machine from [`../configuration.nix`](../configuration.nix) as a Proxmox VM, built in three steps:

1. **OpenTofu** ([`tofu/`](tofu)) creates a *skeleton*: a stock Debian 13 cloud image with a static IP and one SSH key, via cloud-init. Everything goes through the Proxmox API, so OpenTofu needs no SSH access to the node.
2. **nixos-anywhere** ([`scripts/deploy.sh`](scripts/deploy.sh)) logs into the skeleton, kexecs into a NixOS installer, lets **disko** repartition the disk ([`disk-config.nix`](disk-config.nix)), and installs `nixosConfigurations.dar-pve` from this flake ([`host.nix`](host.nix)).
3. **sops-nix** decrypts [`secrets/demo.yaml`](secrets/demo.yaml) on the new machine with its SSH host key. That key was generated *before* the VM existed ([`scripts/new-host-key.sh`](scripts/new-host-key.sh)), made a sops recipient, and copied in by nixos-anywhere.

This directory is a flake of its own, so the repo root keeps its channel-based setup. It pins nixpkgs `nixos-26.05`, disko and sops-nix through `git+https` URLs, which resolve without the GitHub API and work unchanged from a Git mirror.

## Prerequisites

- **Proxmox VE 8.4 or later.** The provider docs note that earlier versions reject a `.qcow2` file name for downloaded images. On the storage that receives the image (default `local`), add **Import** to its content types: *Datacenter → Storage → Edit*.
- **An API token**, exported as `PROXMOX_VE_API_TOKEN=user@realm!name=secret`, and `PROXMOX_VE_ENDPOINT=https://pve:8006/`.
- **Nix with flakes** on the machine you deploy from. `nix develop` provides OpenTofu, nixos-anywhere, sops, age, ssh-to-age and yq.

## Run it

```sh
cd proxmox
nix develop

# 1. Your admin age key (once), so you can edit secrets. Add its public key
#    (age-keygen -y ~/.config/sops/age/keys.txt) to .sops.yaml, then:
#    sops updatekeys secrets/demo.yaml
age-keygen -o ~/.config/sops/age/keys.txt

# 2. A host key for the VM that doesn't exist yet. Keep the private key out
#    of Git: a password manager, or OpenBao/Vault KV.
scripts/new-host-key.sh ~/secure/dar-pve
git commit -am "dar-pve: add host key recipient"

# 3. The skeleton.
cp tofu/terraform.tfvars.example tofu/terraform.tfvars   # edit it
export TF_VAR_state_passphrase='a long passphrase for state encryption'
tofu -chdir=tofu init && tofu -chdir=tofu apply

# 4. Replace it with NixOS.
scripts/deploy.sh dar-pve "$(tofu -chdir=tofu output -raw ipv4_address)" \
  ~/secure/dar-pve ~/.ssh/id_ed25519.pub

# 5. Later changes: rebuild from Git, no reinstall.
nixos-rebuild switch --flake .#dar-pve --target-host root@<address>
```

## Checks

| What | How | Needs |
|---|---|---|
| OpenTofu fmt, validate, plan | `static` job; a plan for new resources doesn't contact the API | nothing |
| System and disko script build | `static` job | nothing |
| Boot + secret decryption | `nix build .#checks.x86_64-linux.dar-pve` | KVM |
| The whole chain on a Debian skeleton | `nix develop .#e2e -c ci/e2e-qemu.sh` | KVM |

The end-to-end script boots the same skeleton as `tofu/main.tf` in plain QEMU: the same image, UEFI, a virtio-scsi disk, and a cloud-init user with a key. It then runs `scripts/deploy.sh`, and checks over SSH that the new system serves the injected host key. It checks that the secret is decrypted and owned by `demo`, that the disk layout is disko's, and that the host can reach the guest agent. Proxmox itself is the one part it doesn't exercise.

## Test keys: public on purpose

[`ci/test-host-key`](ci/test-host-key) is a private key committed so CI can decrypt `secrets/demo.yaml`, which holds only a dummy token. Anything encrypted to it is public. Don't reuse it for a real machine, and give real secrets their own file and creation rule in `.sops.yaml`. No deploy key is committed at all: `deploy.sh` copies `/root/.ssh/authorized_keys` in at install time, so the repo authorizes nobody.
