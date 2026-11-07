# dar-wsl: the dar-nixos machine (../configuration.nix, with zsh.nix and
# home.nix) as a WSL2 distribution, with Ghostty drawn on the Windows desktop
# by WSLg. Only what differs from the base machine lives here.
{ lib, pkgs, ... }:

{
  imports = [ ../configuration.nix ];

  networking.hostName = lib.mkForce "dar-wsl";

  wsl = {
    enable = true;
    # `wsl -d` logs in as the base machine's user instead of NixOS-WSL's
    # "nixos". Set it before the first import: renaming the user of an
    # installed distribution takes the extra steps in NixOS-WSL's docs.
    defaultUser = "demo";
    # WSLg runs Linux GUI apps on the Windows desktop. This gives Mesa the
    # Windows GPU driver (d3d12) instead of software rendering.
    useWindowsDriver = true;
    # Copies .desktop files and icons to /usr/share, where WSLg finds them:
    # Ghostty gets a Windows Start menu entry under the distribution's name.
    startMenuLaunchers = true;
  };

  # WSL starts its own kernel; there is no bootloader to install. NixOS-WSL
  # turns GRUB off, but the systemd-boot the base machine enables has to go
  # too, or the two disagree on how to install a bootloader.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  # The way in is `wsl -d` from the Windows session. sshd would only add a
  # listener, and in WSL's mirrored networking mode it would listen on the
  # Windows host's own network.
  services.openssh.enable = lib.mkForce false;

  # The terminal itself this time, not only its terminfo (configuration.nix):
  # here there is a display to draw on.
  environment.systemPackages = [ pkgs.ghostty ];

  # This system comes from the flake, so its rebuilds do too:
  #   sudo nixos-rebuild switch --flake .#dar-wsl
  # Without channels, a plain `nixos-rebuild switch` fails instead of
  # rebuilding from the starter /etc/nixos/configuration.nix that NixOS-WSL
  # writes, which would replace this machine with a bare NixOS-WSL.
  nix.channel.enable = false;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
