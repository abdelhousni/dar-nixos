# The skeleton: a stock Debian cloud image, booted just long enough for
# nixos-anywhere to kexec into a NixOS installer and overwrite the disk.
# Nothing is configured inside it; NixOS replaces all of it.

resource "proxmox_download_file" "debian" {
  node_name    = var.node_name
  datastore_id = var.image_datastore
  content_type = "import"
  url          = "https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  file_name    = "debian-13-genericcloud-amd64.qcow2"

  # "latest" changes upstream. With the default overwrite = true, a new Debian
  # build would replace this file, and the VM below (which imports from it)
  # would be planned for replacement too. The skeleton's version is irrelevant.
  overwrite = false
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  # UEFI, to match the systemd-boot + ESP layout in disk-config.nix.
  bios    = "ovmf"
  machine = "q35"
  efi_disk {
    datastore_id = var.vm_datastore
    type         = "4m"
    # No Secure Boot keys: NixOS's systemd-boot isn't signed.
    pre_enrolled_keys = false
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  # nixos-anywhere needs at least 1.5 GB to hold its kexec installer in RAM.
  memory {
    dedicated = 2048
  }

  # First SCSI disk on the default virtio-scsi-pci controller: /dev/sda in
  # the guest, which is what disk-config.nix partitions.
  disk {
    datastore_id = var.vm_datastore
    import_from  = proxmox_download_file.debian.id
    interface    = "scsi0"
    size         = var.disk_size
    discard      = "on"
  }

  network_device {
    bridge = var.bridge
  }

  operating_system {
    type = "l26"
  }

  # The port NixOS's qemu-guest-agent binds to. Debian's cloud image has no
  # agent, so don't make OpenTofu wait for one to report an IP address.
  agent {
    enabled = true
    wait_for_ip {
      disabled = true
    }
  }

  initialization {
    datastore_id = var.vm_datastore
    upgrade      = false # an apt upgrade on a system about to be wiped
    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.ipv4_gateway
      }
    }
    user_account {
      username = "debian"
      keys     = [trimspace(var.bootstrap_ssh_public_key)]
    }
  }

  lifecycle {
    # After nixos-anywhere, the disk holds NixOS, not the image it was imported
    # from. Never plan a replacement because the source image changed.
    ignore_changes = [disk[0].import_from]
  }
}
