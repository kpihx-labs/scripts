# 🏗️ KpihX Homelab — Scripts & Automation (`sh/`)

Source of truth for all automation scripts across the Homelab infrastructure. Each subdirectory is designed to be **deployed as-is** to its target node.

---

## 🚀 The Dispatcher (`hsh`)

For convenience, a universal dispatcher `hsh` (inspired by `ksh`) is provided at the root to orchestrate all local administration tasks.

### Installation
```bash
make install
# This symlinks hsh to ~/.local/bin/hsh
```

### Usage
| Command | Action |
| :--- | :--- |
| `hsh status` | Global health audit (connectivity, disk space, latest logs) |
| `hsh backup host` | Local pull of Proxmox LXC 100 snapshot to HDD mirror |
| `hsh backup vault` | Local encrypted backup of Vaultwarden (asks for Master Password) |
| `hsh maintenance` | Trigger the weekly server-side maintenance routine |

---

## 📦 Architecture Overview

```
sh/
├── hsh                → Unified Homelab Dispatcher
├── Makefile           → Automation & Sync targets
├── proxmox/           → Deployed to /root/proxmox/ on kpihx-labs (Hypervisor)
│   ├── backup_docker_host/  → vzdump hook + cloud sync + restore
│   ├── network/             → Watchdog, boot notify, WIFI/WIRED switch
│   ├── lib/notifier.sh      → Telegram notification library
│   ├── maintenance.sh       → Weekly apt + docker prune + reboot
│   └── .env                 → Node-specific secrets (NOT committed)
└── docker_host/       → Deployed to /root/docker_host/ on docker-host (LXC 100)
    ├── backup_vault/        → Vaultwarden backup, encryption, restore
    ├── lib/notifier.sh      → Same library (symlink or copy)
    ├── lib/gen_encrypt_key.sh → GPG key derivation tool
    └── .env                 → Node-specific secrets (NOT committed)
```

---

## 📅 Global Scheduling — All Auto Tasks

| Task | Schedule | Node | Script Path | Log |
| :--- | :--- | :--- | :--- | :--- |
| Vaultwarden cloud backup | **Sun 02:00** | `docker-host` | `/root/docker_host/backup_vault/backup_vault_server.sh` | `/var/log/vault-backup.log` |
| LXC 100 snapshot (vzdump) | **Sat 03:00** | `kpihx-labs` | Proxmox WebUI job | `/var/log/vzdump-*.log` |
| Cloud sync of snapshot | After Sat 03:00 | `kpihx-labs` | `/root/proxmox/backup_docker_host/vzdump-hook.sh` | `/var/log/vzdump-rclone.log` |
| System maintenance + reboot | **Sat 04:00** | `kpihx-labs` | `/root/proxmox/maintenance.sh` | `/var/log/maintenance.log` |
| Network watchdog | **Every 4 min** | `kpihx-labs` | `/root/proxmox/network/network_watchdog.sh` | `/var/log/network_watchdog.log` |
| Boot notification | **On every reboot** | `kpihx-labs` | `/root/proxmox/network/boot_notify.sh` | `/var/log/boot_notify_debug.log` |

---

## 🖥️ Node READMEs

- **[Proxmox (kpihx-labs)](./proxmox/README.md)** — Backup hooks, network watchdog, maintenance
- **[Docker Host (docker-host)](./docker_host/README.md)** — Vaultwarden backup & recovery

---

## 🔐 Security Model

- **Secrets** live in `.env` files on each node — never committed to git.
- **Vault encryption key** is derived live from your Bitwarden Master Password and never stored locally.
- **Server-side vault key** lives in `/root/.vault_secret` (chmod 400) on `docker-host`.
