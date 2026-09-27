# ccbox, ocbox, qcbox, cxbox and ompbox from github.com/guimou/ccbox:
# coding agents (Claude Code, OpenCode, Qwen Code, Codex, oh-my-pi) run in
# a rootless Podman container, with the current directory mounted.
#
# Upstream installs them by curl-ing two files into ~/.local/bin. On NixOS
# that breaks three ways: #!/bin/bash doesn't exist, ~/.local/bin isn't on
# PATH, and the *_VERSION pin files are never downloaded. Packaging the
# whole tree fixes all three.
#
# To update: set rev to a newer commit and hash to "", rebuild, and copy the
# hash from the error message.
{ lib, stdenvNoCC, fetchFromGitHub }:

stdenvNoCC.mkDerivation {
  pname = "ccbox";
  version = "0-unstable-2026-09-21";

  src = fetchFromGitHub {
    owner = "guimou";
    repo = "ccbox";
    rev = "329fcffcfd201ad363b75206d7ef1d4aaa8ac425";
    hash = "sha256-phR2Wl2YXteTQV5NkwDiw3ZarEFoAZzh1HMyodfZjgk=";
  };

  # The launchers resolve their own symlink and look for lib/box-common.sh
  # and the version pin files next to the real script, so keep the tree
  # together and only link the launchers into bin/. The fixup phase then
  # rewrites #!/bin/bash to a bash from the Nix store.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/ccbox $out/bin
    cp -r . $out/share/ccbox
    for b in ccbox ocbox qcbox cxbox ompbox; do
      ln -s $out/share/ccbox/$b $out/bin/$b
    done
    runHook postInstall
  '';

  meta = {
    description = "Run coding agents in a rootless Podman container";
    homepage = "https://github.com/guimou/ccbox";
    license = lib.licenses.asl20;
    mainProgram = "ccbox";
  };
}
