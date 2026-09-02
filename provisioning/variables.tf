variable "proxmox_endpoint" {
  type        = string
  description = "Proxmox API endpoint"
}

variable "proxmox_api_token" {
  type        = string
  sensitive   = true
  description = "Proxmox API token"
}

variable "proxmox_insecure" {
  type        = bool
  default     = false
}

variable "pve_node" {
  type        = string
  description = "Proxmox target node name"
}

variable "vm_id" {
  type        = number
  default     = 200
  description = "VM ID for the DayZ server"
}

variable "vm_name" {
  type        = string
  default     = "dayz-server-vm"
  description = "Name tag for the VM"
}

variable "source_img_file" {
  type        = string
  default     = "local:iso/debian-13-generic-amd64-20260826-2582.img"
  description = "Path to uploaded disk image in Proxmox storage"
}

variable "storage_pool" {
  type        = string
  default     = "local-lvm"
  description = "Target storage pool for the VM root drive"
}

variable "ssh_public_key" {
  type        = string
  description = "Public SSH key injected into Cloud-Init for passwordless access"
}
