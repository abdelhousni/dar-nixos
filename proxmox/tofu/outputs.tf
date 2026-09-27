output "ipv4_address" {
  description = "Address to hand to scripts/deploy.sh."
  value       = split("/", var.ipv4_cidr)[0]
}

output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}
