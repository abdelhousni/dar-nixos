# Working in dar-nixos

A small NixOS machine and the companion repo for the NixOS and Proxmox entries
on [til.housni.eu](https://til.housni.eu/). See [README.md](README.md) for what
each file does.

## Run the checks first

```sh
NIX_PATH=nixpkgs=channel:nixos-26.05 ./ci/eval-checks.sh   # needs only Nix
nix-build test.nix -I nixpkgs=channel:nixos-26.05          # needs KVM
```

Without a usable Nix daemon, run the evaluation checks in the image that
`.gitlab-ci.yml` pins:

```sh
podman run --rm -v "$PWD":/w:ro,Z -w /w -e NIX_PATH=nixpkgs=channel:nixos-26.05 \
  docker.io/nixos/nix:2.34.8 ./ci/eval-checks.sh
```

Without KVM, say the VM test didn't run and let CI run it. `proxmox/` is a flake
of its own, with its own checks in [`proxmox/README.md`](proxmox/README.md).

## Rules

- **This repository is public.** No homelab addresses, hostnames or zone data,
  no links to private repositories, and no secrets. The only committed private
  key is `proxmox/ci/test-host-key`, which is public on purpose.
- A TIL entry links to files here, so a rename or removal has to update the
  entry too, and a file an entry links to has to be on `main`.
- Commits are authored by
  `abdelhousni <23284113+abdelhousni@users.noreply.github.com>`; check
  `git var GIT_AUTHOR_IDENT` before the first commit. Credit Claude only with a
  `Co-Authored-By` trailer.
- Commit messages and pull request titles follow
  [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`,
  `docs:`, `chore:`, and so on).

## Stay vanilla (strongly recommended)

Use the stock, upstream tool and its defaults before anything else: stock VS
Code with extensions from each tool's own vendor only (no VS Code fork such as
Cursor or Antigravity), project configuration in the repository
(`.devcontainer/`, `.vscode/`) rather than on the workstation, `kubectl`
before any cluster UI, Claude Code as the only AI assistant, and upstream
tools, roles and collections used as published, unpatched. Depart from this
only when the stock tool can't do the job, and say why in the pull request.
