# ccbox for the demo user: the package from pkgs/ccbox.nix, and the rootless
# Podman it runs on. No PATH change is needed: users.users.<name>.packages
# land in /etc/profiles/per-user/<name>/bin, which is already on PATH.
{ pkgs, ... }:

{
  # Rootless is enough: NixOS gives every isNormalUser account a subuid and
  # subgid range by default (autoSubUidGidRange).
  virtualisation.podman.enable = true;

  users.users.demo.packages = [
    (pkgs.callPackage ./pkgs/ccbox.nix { })
  ];
}
