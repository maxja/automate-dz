resource "proxmox_virtual_environment_file" "cloud_user_config" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.pve_node

  source_raw {
    data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
      hostname = var.vm_name,
      ssh_key  = var.ssh_public_key
    })
    file_name = "dayz-user-data.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "dz_vm" {
  name        = var.vm_name
  node_name   = var.pve_node
  vm_id       = var.vm_id
  description = "Managed by OpenTofu - Dedicated DayZ Game Server"

  agent {
    enabled = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 16384
  }

  disk {
    datastore_id = var.storage_pool
    file_id      = var.source_img_file
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    size         = 40
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id      = var.storage_pool
    user_data_file_id = proxmox_virtual_environment_file.cloud_user_config.id

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
