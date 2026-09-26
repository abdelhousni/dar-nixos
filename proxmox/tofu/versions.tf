terraform {
  required_version = ">= 1.8"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.114"
    }
  }

  # The state records every VM attribute, cloud-init settings included.
  # Encrypt it (OpenTofu 1.7+). The passphrase comes from TF_VAR_state_passphrase;
  # in CI, prefer the openbao key provider (transit engine) over a passphrase.
  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }
    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }
    state {
      method   = method.aes_gcm.state
      enforced = true
    }
    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

# Endpoint and API token come from PROXMOX_VE_ENDPOINT and PROXMOX_VE_API_TOKEN,
# so no credential is written in a .tf or .tfvars file. Everything below goes
# through the Proxmox API: no SSH access to the node is needed.
provider "proxmox" {
  insecure = var.proxmox_insecure
}
