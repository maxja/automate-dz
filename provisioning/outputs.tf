output "vm_id" {
  value       = proxmox_virtual_environment_vm.dz_vm.vm_id
  description = "Provisioned VM ID"
}

output "vm_name" {
  value       = proxmox_virtual_environment_vm.dz_vm.name
  description = "Provisioned VM Name"
}

output "vm_ip_address" {
  value       = proxmox_virtual_environment_vm.dz_vm.ipv4_addresses
  description = "Assigned IP addresses of the VM reported by QEMU Agent"
}

output "vm_primary_ip" {
  value = one([
    for ip in flatten(proxmox_virtual_environment_vm.dz_vm.ipv4_addresses) :
    ip if !startswith(ip, "127.")
  ])
  description = "Primary non-loopback IPv4 address (from QEMU agent)"
}
