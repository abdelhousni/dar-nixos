# dar-pve: the dar-nixos machine (../configuration.nix, with zsh.nix) as a
# Proxmox VM. Only what differs from the repo's base machine lives here.
{ lib, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix") # virtio drivers in the initrd
    ../configuration.nix
    ./disk-config.nix
  ];

  networking.hostName = lib.mkForce "dar-pve";

  # nixos-anywhere installs from a kexec'd installer, where writing UEFI
  # variables isn't guaranteed. Without them, bootctl still installs the
  # fallback loader \EFI\BOOT\BOOTX64.EFI, which the firmware boots when no
  # NVRAM entry matches (the skeleton's Debian entry points at a wiped disk).
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # Lets Proxmox (and the OpenTofu provider) see the VM's IP address and shut
  # it down cleanly. The VM needs `agent { enabled = true }` on the Proxmox side.
  services.qemuGuest.enable = true;

  # Deployment access. No key is committed here: nixos-anywhere copies
  # /root/.ssh/authorized_keys in with --extra-files (see scripts/deploy.sh),
  # so the repo never authorizes anyone. Key-only root login is what later
  # `nixos-rebuild --target-host root@...` runs need.
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # Secrets. sops-nix decrypts them at activation with the age key derived
  # from /etc/ssh/ssh_host_ed25519_key (its default when openssh is on).
  # That host key is generated BEFORE the VM exists and copied in by
  # nixos-anywhere, so its public half can be a recipient in .sops.yaml.
  sops.defaultSopsFile = ./secrets/demo.yaml;
  sops.secrets.demo-api-token.owner = "demo";
}
