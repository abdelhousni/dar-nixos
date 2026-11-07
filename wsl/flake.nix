{
  description = "dar-nixos on WSL2: the same machine as a WSL distribution, with Ghostty on the Windows desktop through WSLg";

  inputs = {
    # git+https rather than github, as in ../proxmox: no GitHub API, so the
    # same URLs work from a mirror.
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&shallow=1";
    # NixOS-WSL's release branch for the same NixOS release.
    nixos-wsl.url = "git+https://github.com/nix-community/NixOS-WSL?ref=release-26.05";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixos-wsl }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.dar-wsl = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          nixos-wsl.nixosModules.default
          ./host.nix
        ];
      };

      # `sudo nix run .#tarballBuilder` writes nixos.wsl: nixos-install into
      # a directory, packed as the file WSL imports. Needs root, not KVM.
      packages.${system}.tarballBuilder =
        self.nixosConfigurations.dar-wsl.config.system.build.tarballBuilder;
    };
}
