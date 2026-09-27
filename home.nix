# Home Manager as a NixOS module: the demo user's dotfiles, built and
# rolled back together with the system by `nixos-rebuild`.
#
# Companion to https://abdelhousni.github.io/til/nixos/home-manager-nixos-module.html
#
# On a real machine the TIL uses a channel instead of the fetchTarball below:
#
#   sudo nix-channel --add https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz home-manager
#   sudo nix-channel --update
#
# and `imports = [ <home-manager/nixos> ];`. This repo pins a commit with its
# hash so the same file also evaluates in CI and in the proxmox/ flake, where
# there is no home-manager channel.
{ ... }:

let
  # release-26.05. Keep it on the same release as nixpkgs: a mismatch is
  # only a warning, and ci/eval-checks.sh turns that warning into a failure.
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/a6631107a83ceab5872f298a2ea710859c80c4cb.tar.gz";
    sha256 = "0n9149cpiv0a3xhyjs64w9xpv95sg5f4h20gnxilz3djq6n7ai2n";
  };
in
{
  imports = [ "${home-manager}/nixos" ];

  home-manager = {
    # Use the system's nixpkgs (and its overlays and config) instead of a
    # second, separately configured instance per user.
    useGlobalPkgs = true;
    # home.packages go into /etc/profiles/per-user/demo, like
    # users.users.demo.packages, instead of ~/.nix-profile.
    useUserPackages = true;
    # A file already in the way of a managed one is renamed to *.backup
    # instead of failing activation. Only once: if *.backup exists too,
    # activation fails again (see test.nix) unless overwriteBackup is set.
    backupFileExtension = "backup";

    users.demo = { pkgs, ... }: {
      # Like system.stateVersion: the release this user's config was first
      # written for. Not the Home Manager version; don't bump it to upgrade.
      home.stateVersion = "26.05";

      home.packages = [ pkgs.ripgrep ];

      # Writes ~/.config/git/config. Since 25.11 the identity lives under
      # settings; userName/userEmail are renamed options.
      programs.git = {
        enable = true;
        settings.user = {
          name = "Demo";
          email = "demo@example.invalid";
        };
      };

      # Any file, not only programs.*: a symlink into the Nix store.
      xdg.configFile."dar-nixos/hello.txt".text = ''
        Managed by Home Manager, from dar-nixos/home.nix.
      '';

      # Zsh stays in zsh.nix, at the system level. Home Manager doesn't write
      # ~/.zshrc unless programs.zsh.enable is set here, and then its
      # home.sessionVariables are sourced from that file; without it they
      # aren't loaded by anything.
    };
  };
}
