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
┌──────────────────────────────────────────────────────┐
│                    Proxmox Host                      │
│                                                      │
│  ┌──────────────────────┐   ┌──────────────────────┐ │
│  │    Game Server VM    │   │   Monitoring LXC     │ │
│  │                      │   │                      │ │
│  │  DayZ DS             │──▶│  Loki                │ │
│  │  node_exporter   ────┼──▶│  Prometheus          │ │
│  │  Promtail            │   │  Grafana             │ │
│  └──────────────────────┘   └──────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

- Game server runs the DayZ DS plus two lightweight exporters: **Promtail** (ships logs) and **node_exporter** (exposes metrics)
- A dedicated **Proxmox LXC container** runs the full observability stack: Loki, Prometheus, and Grafana
- Nothing from the monitoring stack is installed on the game server VM
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
# .env.secrets  (not committed — covered by .gitignore)
# Copy example.env and replace placeholders with op:// secret references.

# Proxmox
PROXMOX_VE_ENDPOINT=https://{proxmox_host}:8006
PROXMOX_VE_API_TOKEN=op://Homelab/Proxmox/api-token
TF_VAR_proxmox_endpoint=${PROXMOX_VE_ENDPOINT}
TF_VAR_proxmox_api_token=${PROXMOX_VE_API_TOKEN}
TF_VAR_proxmox_insecure=false
TF_VAR_pve_node={node_name}
TF_VAR_ssh_public_key=op://Homelab/SSH/public-key

# Steam (account must own DayZ; used by SteamCMD to download App ID 223350)
DAYZ_STEAM_USERNAME=op://Homelab/Steam/username
DAYZ_STEAM_PASSWORD=op://Homelab/Steam/password

# DayZ server
DAYZ_SERVER_PASSWORD=op://Homelab/DayZ Server/server-password   # player join password
DAYZ_ADMIN_PASSWORD=op://Homelab/DayZ Server/admin-password     # in-game admin (passwordAdmin)
DAYZ_RCON_PASSWORD=op://Homelab/DayZ Server/rcon-password       # BattlEye/RCON channel
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

**Phase 0 — Housekeeping**
- [x] Secrets template (`example.env`) with 1Password references
- [x] Makefile targets: `inventory`, `galaxy`, `clean`
- [x] `.gitignore` covers generated files and secrets

**Phase 1 — Ansible scaffolding**
- [x] Role structure: `baseline`, `dayz_server`, `telemetry_agent`, `monitoring`
- [x] Group vars: `game_servers`, `observability`, `all`
- [x] `serverDZ.cfg` and systemd unit templates
- [x] Promtail config template

**Phase 2 — Observability LXC + second inventory host**
- [ ] Terraform: Proxmox LXC container for monitoring stack
- [ ] `make inventory` updated to include the LXC host in the `observability` group
- [ ] Ansible: `monitoring` role implemented (Loki, Prometheus, Grafana)
- [ ] Prometheus scrape config targeting game server `node_exporter`
- [ ] Grafana datasources provisioned automatically (Loki + Prometheus)

**Phase 3 — Dashboards and log pipelines**
- [ ] Grafana dashboards: server health, DayZ session metrics
- [ ] Promtail pipeline: parse DayZ admin log for in-game events (kills, connects, etc.)
- [ ] Log rotation on both the game server and LXC

**Phase 4 — Provider abstraction**
- [ ] Refactor provisioning into modules (Proxmox-specific vs. common interface)
- [ ] Hetzner Cloud provider module
- [ ] OVH / Vultr / generic VPS module
- [ ] Dynamic inventory (provider-native or Terraform-state-driven)
