# Boots dar-pve in a VM and checks the parts that differ from the base
# machine. The disko layout is evaluated but not applied: the test VM
# brings its own disks and overrides fileSystems.
{ pkgs, hostModules }:

pkgs.testers.runNixOSTest {
  name = "dar-pve";

  nodes.machine = { lib, ... }: {
    imports = hostModules;

    # Stand-in for what nixos-anywhere --extra-files does on a real install:
    # the pre-generated host key is on disk before sops-nix activates.
    # The test key's private half is public (committed), so VM tests only.
    system.activationScripts.injectHostKey.text = ''
      install -D -m 600 ${./ci/test-host-key} /etc/ssh/ssh_host_ed25519_key
      install -D -m 644 ${./ci/test-host-key.pub} /etc/ssh/ssh_host_ed25519_key.pub
    '';
    system.activationScripts.setupSecrets.deps = [ "injectHostKey" ];
  };

  qemu.forceAccel = true;

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.succeed("grep -qx dar-pve /proc/sys/kernel/hostname")
    # The agent starts when Proxmox adds its virtio port, which this test VM
    # doesn't have; check the unit is installed and hooked to that device.
    machine.succeed("systemctl cat qemu-guest-agent.service")
    machine.succeed("grep -rq org.qemu.guest_agent.0 /etc/udev/rules.d/")

    # sops-nix decrypted the secret with the host key, for the demo user only.
    machine.succeed("grep -q '^not-a-real-token-' /run/secrets/demo-api-token")
    assert machine.succeed("stat -c '%U %a' /run/secrets/demo-api-token").strip() == "demo 400"
    machine.fail("su -l nobody -s /bin/sh -c 'cat /run/secrets/demo-api-token'")

    # sshd kept the injected key instead of generating its own.
    machine.succeed("cmp /etc/ssh/ssh_host_ed25519_key.pub ${./ci/test-host-key.pub}")
    machine.succeed("grep -qx 'PermitRootLogin prohibit-password' /etc/ssh/sshd_config")
  '';
}
