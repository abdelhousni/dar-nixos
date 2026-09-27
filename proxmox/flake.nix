{
  description = "dar-nixos on Proxmox: a skeleton VM from OpenTofu, turned into NixOS by nixos-anywhere, with sops-nix secrets";

  inputs = {
    # git+https rather than github: resolves branches with git itself, not the
    # GitHub API, so the same URLs work from a mirror (e.g. an on-prem GitLab).
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&shallow=1";
    disko.url = "git+https://github.com/nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    sops-nix.url = "git+https://github.com/Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, sops-nix }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.dar-pve = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./host.nix
        ];
      };

      # `nix flake check` boots dar-pve in a VM (needs KVM) and checks the
      # secret was decrypted with the injected host key.
      checks.${system}.dar-pve = import ./test.nix {
        inherit pkgs;
        hostModules = [ disko.nixosModules.disko sops-nix.nixosModules.sops ./host.nix ];
      };

      # Everything the scripts and the OpenTofu module need.
      devShells.${system} = rec {
        default = pkgs.mkShell {
          packages = with pkgs; [ opentofu nixos-anywhere sops age ssh-to-age openssh yq-go ];
        };
        # ci/e2e-qemu.sh: the same, plus QEMU and UEFI firmware to run the
        # skeleton locally instead of on Proxmox.
        e2e = pkgs.mkShell {
          inputsFrom = [ default ];
          packages = with pkgs; [ qemu_kvm cdrkit python3 ];
          OVMF_CODE = "${pkgs.OVMF.fd}/FV/OVMF_CODE.fd";
          OVMF_VARS = "${pkgs.OVMF.fd}/FV/OVMF_VARS.fd";
        };
      };
    };
}
