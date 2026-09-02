# DayZ Infrastructure Automation

End-to-end automation for provisioning, deploying, and configuring a self-hosted DayZ game server environment — including a dedicated observability stack with metrics, logs, and visualization.

Designed first for **Proxmox** home-lab setups, with a roadmap toward cloud providers (Hetzner, OVH, Vultr, and others).

---

## What This Project Does

Two servers, fully automated:

| Server | Purpose |
|---|---|
| **Game Server** | DayZ dedicated server: installs via SteamCMD, configured and managed as a systemd service |
| **Observability Server** | Collects telemetry, in-game metrics, and server logs — visualized via Grafana and Loki with log rotation |

Everything from VM creation to running services is driven by `make` targets. Secrets are stored in **1Password** and injected at runtime via `op run` — nothing sensitive lives in this repository.

---

## Architecture

```
┌─────────────────────────────────────────┐
│             Proxmox Host                │
│                                         │
│  ┌──────────────────┐  ┌─────────────┐  │
│  │  Game Server VM  │  │  Obs Server │  │
│  │                  │  │     VM      │  │
│  │  DayZ DS         │──▶  Promtail   │  │
│  │  node_exporter   │  │  Loki       │  │
│  │  UFW             │  │  Prometheus │  │
│  └──────────────────┘  │  Grafana    │  │
│                         └─────────────┘  │
└─────────────────────────────────────────┘
```

- Game server pushes logs to Loki via **Promtail** and exposes metrics via **Prometheus node_exporter**
- Observability server scrapes, stores, and visualizes everything via **Grafana**
- Log rotation is managed on both ends

---

## Stack

| Layer | Tool |
|---|---|
| Provisioning | OpenTofu (Terraform-compatible) |
| Configuration | Ansible |
| Secrets | 1Password (`op run`) |
| Hypervisor | Proxmox VE |
| OS | Debian (cloud image, via cloud-init) |
| Game Server | DayZ Standalone (Steam App 223350) |
| Metrics | Prometheus + node_exporter |
| Logs | Loki + Promtail |
| Visualization | Grafana |

---

## Workflow

```
make init        →  initialize OpenTofu backend
make plan        →  preview infrastructure changes (dry run)
make provision   →  create VMs (cloud-init bootstraps OS)
make inventory   →  read VM IPs from Terraform state → write Ansible inventory
make galaxy      →  install Ansible Galaxy collections (one-time)
make configure   →  run Ansible: OS baseline → game server → observability stack
make destroy     →  tear down all infrastructure
```

---

## Prerequisites

- [OpenTofu](https://opentofu.org/) (`tofu`)
- [Ansible](https://docs.ansible.com/) (`ansible`, `ansible-galaxy`)
- [1Password CLI](https://developer.1password.com/docs/cli/) (`op`)
- SSH key pair loaded in your SSH agent
- Proxmox VE node with API access
- A Steam account that owns DayZ (required to download the dedicated server)
- Debian cloud image uploaded to Proxmox storage

---

## Secrets Setup

Secrets are never stored in this repo. They live in 1Password and are referenced in `.env.secrets` using [secret references](https://developer.1password.com/docs/cli/secret-references/):

```sh
# .env.secrets  (not committed — add to .gitignore)

# Proxmox
TF_VAR_proxmox_endpoint=op://Homelab/Proxmox/endpoint
TF_VAR_proxmox_api_token=op://Homelab/Proxmox/api-token
TF_VAR_ssh_public_key=op://Homelab/SSH/public-key

# Steam (required to download DayZ DS)
DAYZ_STEAM_USERNAME=op://Homelab/Steam/username
DAYZ_STEAM_PASSWORD=op://Homelab/Steam/password

# DayZ server
DAYZ_SERVER_PASSWORD=op://Homelab/DayZ Server/server-password
DAYZ_ADMIN_PASSWORD=op://Homelab/DayZ Server/admin-password
```

All `make` targets that need secrets are prefixed with `op run --env-file=.env.secrets --`, so secrets are resolved at runtime and never written to disk.

---

## Proxmox Setup

### API Token

Create a dedicated API token for OpenTofu:

**Datacenter → Permissions → API Tokens → Add**

- User: `root@pam` (or a dedicated user with appropriate permissions)
- Token ID: e.g. `opentofu`
- Uncheck **Privilege Separation** if you want the token to inherit full root permissions

Copy the generated token secret immediately — it is only shown once. Store it in 1Password at the path referenced in `.env.secrets`.

### Cloud Image

Download a Debian generic cloud image and upload it to Proxmox local storage:

```sh
# On the Proxmox node
wget https://cloud.debian.org/images/cloud/trixie/latest/debian-13-generic-amd64.qcow2
```

Upload via **Datacenter → Storage → local → ISO Images → Upload**, or place it directly under `/var/lib/vz/template/iso/`. Update `source_img_file` in `provisioning/variables.tf` to match the uploaded filename.

### SSH Agent

Ansible connects to VMs using the same SSH key injected by cloud-init. Make sure the corresponding private key is loaded in your agent before running `make configure`:

```sh
ssh-add ~/.ssh/your_key
```

---

## Configuration Reference

Provisioning variables are defined in `provisioning/variables.tf`. Key options:

| Variable | Default | Description |
|---|---|---|
| `vm_id` | `200` | Proxmox VM ID for the game server |
| `vm_name` | `dayz-server-vm` | VM display name |
| `storage_pool` | `local-lvm` | Storage pool for VM disk |
| `source_img_file` | *(Debian 13 image path)* | Cloud image reference in Proxmox |

---

## Roadmap

- [x] Proxmox VM provisioning via OpenTofu
- [x] OS bootstrap via cloud-init (SSH, user, packages)
- [ ] Ansible: OS baseline role (UFW, SSH hardening)
- [ ] Ansible: DayZ server role (SteamCMD, config, systemd)
- [ ] Ansible: Observability role (Loki, Promtail, Prometheus, Grafana)
- [ ] Grafana dashboards for game metrics and server health
- [ ] In-game event log parsing via Promtail pipeline
- [ ] Provider abstraction: Hetzner Cloud
- [ ] Provider abstraction: OVH / Vultr / generic VPS
- [ ] Dynamic inventory (Proxmox API / provider-native)
