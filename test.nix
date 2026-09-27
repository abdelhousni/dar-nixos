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

    # home.nix: Home Manager activates as a system unit at boot, as the user,
    # ordered before logins are allowed.
    machine.wait_for_unit("home-manager-demo.service")
    before = machine.succeed("systemctl show -p Before --value home-manager-demo.service")
    assert "systemd-user-sessions.service" in before, before
    machine.succeed("systemctl show -p User --value home-manager-demo.service | grep -qx demo")

    # Managed files are symlinks into the Nix store, and git reads them.
    machine.succeed("readlink -f /home/demo/.config/git/config | grep -q '^/nix/store/'")
    name = machine.succeed("su -l demo -c 'git config --get user.name'").strip()
    assert name == "Demo", name
    machine.succeed("grep -q 'Managed by Home Manager' /home/demo/.config/dar-nixos/hello.txt")

    # useUserPackages: home.packages land in the per-user profile, on PATH.
    machine.succeed("test -x /etc/profiles/per-user/demo/bin/rg")
    machine.succeed("su -l demo -c 'command -v rg' | grep -q '^/etc/profiles/per-user/demo/'")
    machine.fail("test -e /home/demo/.nix-profile/bin/rg")

    # A file in the way of a managed one: with backupFileExtension set, the
    # next activation moves it aside instead of failing.
    hello = "/home/demo/.config/dar-nixos/hello.txt"
    def put_file_in_the_way():
        machine.succeed(f"su -l demo -c 'rm {hello} && echo edited by hand > {hello}'")
    put_file_in_the_way()
    machine.succeed("systemctl restart home-manager-demo.service")
    machine.succeed(f"grep -qx 'edited by hand' {hello}.backup")
    machine.succeed(f"readlink -f {hello} | grep -q '^/nix/store/'")

    # Only once: the next collision would overwrite hello.txt.backup, so
    # activation fails instead (overwriteBackup = true would allow it).
    put_file_in_the_way()
    machine.fail("systemctl restart home-manager-demo.service")
    journal = machine.succeed("journalctl -u home-manager-demo.service --no-pager")
    assert "would be clobbered by backing up" in journal, journal
    machine.succeed(f"grep -qx 'edited by hand' {hello}")

    # Deal with the backup, and activation works again.
    machine.succeed(f"rm {hello}.backup")
    machine.succeed("systemctl restart home-manager-demo.service")
    machine.succeed(f"readlink -f {hello} | grep -q '^/nix/store/'")
  '';
}
