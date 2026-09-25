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
  '';
}
