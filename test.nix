# Boots configuration.nix in a VM and checks what the TIL claims about it.
#
#   nix-build test.nix -I nixpkgs=channel:nixos-26.05
#
# Interactive (drops you into a Python REPL driving the VM):
#   $(nix-build test.nix -A driverInteractive -I nixpkgs=channel:nixos-26.05)/bin/nixos-test-driver
{ pkgs ? import <nixpkgs> { } }:

pkgs.testers.runNixOSTest {
  name = "dar-nixos";

  nodes.machine = { ... }: {
    imports = [ ./configuration.nix ];
  };

  # Fail if KVM isn't usable instead of silently falling back to software
  # emulation (TCG), which works but is slow enough to time out a CI job.
  qemu.forceAccel = true;

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # services.openssh.enable is a module: unit running, port open.
    machine.wait_for_unit("sshd.service")
    machine.wait_for_open_port(22)

    # environment.systemPackages put git and htop on the system PATH.
    machine.succeed("git --version")
    machine.succeed("htop --version")

    # The hostname came from the same file.
    machine.succeed("grep -qx dar-nixos /proc/sys/kernel/hostname")

    # nix.gc.automatic created a timer; nothing runs a GC by hand.
    machine.succeed("systemctl list-timers | grep -q nix-gc")

    # The running system is a build output in the Nix store, not files
    # edited in place. (Test VMs boot it directly, so there is no system
    # profile or generation list here; that exists on a real install.)
    machine.succeed("readlink -f /run/current-system | grep -q '^/nix/store/'")

    # zsh.nix: zsh is the login shell, set declaratively.
    machine.succeed("getent passwd demo | grep -q '/bin/zsh$'")
    # An empty ~/.zshrc skips zsh-newuser-install, which would wait for input.
    machine.succeed("su -l demo -c 'touch ~/.zshrc'")

    # NixOS aliases are written after Oh My Zsh, so gc is the NixOS one,
    # not the git plugin's `git commit --verbose`.
    gc = machine.succeed("su -l demo -c \"zsh -ic 'alias gc'\" 2>&1")
    assert "nix-collect-garbage" in gc, gc

    # The fzf plugin (added by programs.fzf) finds fzf: no "[oh-my-zsh] ...
    # Cannot find" warning when a shell starts.
    startup = machine.succeed("su -l demo -c \"zsh -ic exit\" 2>&1")
    assert "[oh-my-zsh]" not in startup, startup

    # compinit ran once, from Oh My Zsh: its dump exists, NixOS's doesn't.
    machine.succeed("ls /home/demo/.zcompdump-dar-nixos-*")
    machine.fail("test -e /home/demo/.zcompdump")

    # ccbox.nix: the launchers are on demo's PATH through the per-user
    # profile, with no ~/.local/bin and no PATH edit.
    where = machine.succeed("su -l demo -c 'command -v ccbox'").strip()
    assert where == "/etc/profiles/per-user/demo/bin/ccbox", where
    # Upstream's #!/bin/bash doesn't exist on NixOS; the package rewrote it.
    machine.succeed("head -1 \"$(readlink -f " + where + ")\" | grep -q '^#!/nix/store/.*/bin/bash$'")
    # Through the symlink, the launcher still finds lib/box-common.sh.
    usage = machine.succeed("su -l demo -c 'ccbox --help'")
    assert "Run Claude Code in a container" in usage, usage
    machine.succeed("su -l demo -c 'command -v ocbox qcbox cxbox ompbox'")

    # Rootless Podman for demo: a subuid range was allocated, and podman
    # runs as the user without root.
    machine.succeed("grep -q '^demo:' /etc/subuid")
    rootless = machine.succeed("su -l demo -c \"podman info --format '{{.Host.Security.Rootless}}'\"").strip()
    assert rootless == "true", rootless
  '';
}
