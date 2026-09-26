variable "state_passphrase" {
  description = "Passphrase for OpenTofu state and plan encryption (16+ characters). Set TF_VAR_state_passphrase."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Skip TLS verification of the Proxmox API (self-signed certificate)."
  type        = bool
  default     = false
}

variable "node_name" {
  description = "Proxmox node to create the VM on."
  type        = string
}

variable "vm_name" {
  description = "VM name. Also the nixosConfigurations entry nixos-anywhere installs."
  type        = string
  default     = "dar-pve"
}

variable "vm_id" {
  description = "Proxmox VM ID. null lets Proxmox pick the next free one."
  type        = number
  default     = null
}

variable "image_datastore" {
  description = "Datastore for the downloaded cloud image. Its content types must include Import."
  type        = string
  default     = "local"
}

variable "vm_datastore" {
  description = "Datastore for the VM disks, EFI vars and cloud-init drive."
  type        = string
  default     = "local-lvm"
}

variable "disk_size" {
  description = "Disk size in GB. The whole disk is repartitioned by disko."
  type        = number
  default     = 20
}

variable "bridge" {
  description = "Network bridge."
  type        = string
  default     = "vmbr0"
}

variable "ipv4_cidr" {
  description = "Static IPv4 address in CIDR notation, e.g. 192.168.1.50/24. NixOS then takes over with DHCP unless you configure otherwise."
  type        = string
}

variable "ipv4_gateway" {
  description = "IPv4 gateway."
  type        = string
}

variable "bootstrap_ssh_public_key" {
  description = "SSH public key allowed to log in to the skeleton as `debian`, for nixos-anywhere."
  type        = string
}
