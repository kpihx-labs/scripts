# 🛡️ Proxmox Guest Backups & Disaster Recovery

This guide covers all backup and restoration operations for the Proxmox hypervisor (`kpihx-labs`) and its guest `docker-host` (LXC 100).

---

## 📜 Script Manifest

### 1. `vzdump-hook.sh` — Automatic Post-Backup Cloud Sync
| | |
| :--- | :--- |
| **Deployed at** | `/root/proxmox/backup_docker_host/vzdump-hook.sh` |
| **Trigger** | Automatically by Proxmox at phase `job-end` after every `vzdump` job |
| **Schedule** | Triggered by Proxmox scheduled backup — **Every Saturday at 03:00** |
| **What it does** | Detects the latest `.zst` / `.tar.gz` archive in `/var/lib/vz/dump/`, uploads it to `gdrive-x:Homelab/Backups/Docker_Host`, then purges older Cloud archives |
| **Retention** | Cloud: **1 most recent** only |
| **Logs** | `/var/log/vzdump-rclone.log` |
| **Notifications** | Telegram (INFO at start, SUCCESS or ERROR at end) |

### 2. `backup_docker_host_server.sh` — Manual Cloud Push from PVE
| | |
| :--- | :--- |
| **Deployed at** | `/root/proxmox/backup_docker_host/backup_docker_host_server.sh` |
| **Trigger** | Manual (`sudo /root/proxmox/backup_docker_host/backup_docker_host_server.sh`) |
| **What it does** | Same logic as the hook but can be run anytime without waiting for a scheduled vzdump. Identifies the latest local archive and pushes it to Cloud |
| **Retention** | Cloud: **1 most recent** only (purges others after upload) |
| **Logs** | `/var/log/vzdump-rclone.log` |
| **Notifications** | Telegram (INFO at start, SUCCESS or ERROR at end) |

### 3. `backup_docker_host_local.sh` — Manual Local HDD Mirror (run from PC)
| | |
| :--- | :--- |
| **Deployed at** | `/home/kpihx/Work/Homelab/sh/proxmox/backup_docker_host/backup_docker_host_local.sh` (local repo only) |
| **Trigger** | Manual from your local PC |
| **Prerequisites** | External HDD mounted at `/media/kpihx/KpihX-Backup` & SSH alias `homelab` configured |
| **What it does** | Phase 1: `rsync` over SSH from PVE `/var/lib/vz/dump/` → HDD `KpihX-Backup/Homelab/Backups/Docker_Host/`. Phase 2: Applies HDD retention. Phase 3: Pushes latest HDD archive to Cloud |
| **Retention** | HDD: **2 most recent** (older are automatically deleted) |
| **Notifications** | Telegram (SUCCESS or ERROR at end) |

### 4. `restore_docker_host.sh` — Disaster Recovery (Cloud → PVE)
| | |
| :--- | :--- |
| **Deployed at** | `/root/proxmox/backup_docker_host/restore_docker_host.sh` |
| **Trigger** | Manual (only in disaster scenarios) |
| **What it does** | Fetches the most recent archive from `gdrive-x:Homelab/Backups/Docker_Host` and downloads it to `/var/lib/vz/dump/` on the PVE host |
| **Notifications** | Telegram (INFO at start, SUCCESS or ERROR at end) |

### 5. `vzdump.conf` — Proxmox Core Configuration
| | |
| :--- | :--- |
| **Deployed at** | `/etc/vzdump.conf` (system file — auto-applied on deploy) |
| **Purpose** | Registers `vzdump-hook.sh` as a post-backup hook for all Proxmox backup jobs |
| **Key setting** | `script: /root/proxmox/backup_docker_host/vzdump-hook.sh` |

---

## ⚙️ Setup Procedure (First Deploy or Fresh Node)

1. **Ensure `rclone` is configured for root**:
   ```bash
   sudo rclone config  # Configure gdrive-x remote
   sudo ls /root/.config/rclone/rclone.conf  # Verify config exists
   ```

2. **Deploy the scripts**:
   ```bash
   # From your local machine
   rsync -avzL --delete /path/to/sh/proxmox/ ivann@kpihx-labs:/tmp/proxmox/
   ssh -t kpihx-labs "sudo rm -rf /root/proxmox && sudo mv /tmp/proxmox /root/proxmox && sudo chown -R root:root /root/proxmox && sudo chmod +x /root/proxmox/backup_docker_host/*.sh"
   ```

3. **Register the vzdump hook**:
   ```bash
   ssh -t kpihx-labs "sudo cp /root/proxmox/backup_docker_host/vzdump.conf /etc/vzdump.conf"
   ```

4. **Configure the `.env`** (only once per server, contains secrets):
   ```bash
   ssh -t kpihx-labs "sudo nano /root/proxmox/.env"
   # Required variables:
   # TELEGRAM_HOMELAB_TOKEN=<your-bot-token>
   # CHAT_ID=<your-chat-id>
   ```

5. **Configure scheduled Proxmox backup** in the WebUI or via CLI:
   - **Schedule**: Every Saturday at 03:00 (`0 3 * * 6`)
   - **Target**: CT 100 (`docker-host`)
   - **Mode**: `snapshot` or `stop`
   - **Local retention**: 2 copies (managed by PVE itself)

---

## 🏗️ Restoration Procedure — Step by Step

This procedure covers a full disaster where the `docker-host` container (LXC 100) is lost.

### Step 1: Pull the Archive Back from Cloud
The PVE host must still be alive and `rclone` must be configured.
```bash
# Run on the PVE host
sudo /root/proxmox/backup_docker_host/restore_docker_host.sh
```
This will automatically:
1. List all archives on `gdrive-x:Homelab/Backups/Docker_Host`.
2. Download the most recent one to `/var/lib/vz/dump/`.
3. Send you a Telegram notification on success or failure.

### Step 2: Restore the Container
```bash
# Replace 100 with your VMID, and adjust the filename
sudo pct restore 100 /var/lib/vz/dump/vzdump-lxc-100-YYYY_MM_DD-HH_MM_SS.tar.zst \
    --storage local-lvm \
    --unprivileged 1

# Or using qmrestore for VMs:
# sudo qmrestore /var/lib/vz/dump/vzdump-qemu-100-...vma 100
```

### Step 3: Boot and Verify
```bash
sudo pct start 100
sudo pct status 100
sudo pct exec 100 -- docker ps
```

---

## 📅 Scheduling Summary

| Job | Schedule | Trigger | Location |
| :--- | :--- | :--- | :--- |
| Local snapshot (vzdump) | **Sat 03:00** | Proxmox WebUI / cron | Proxmox native |
| Cloud sync hook | After vzdump succeeds | `vzdump-hook.sh` auto-called | PVE host |
| Local HDD mirror | **Manual** | `backup_docker_host_local.sh` from PC | Local machine |

---

## 🗂️ Storage Retention Summary

| Destination | Path | Retention |
| :--- | :--- | :--- |
| PVE local | `/var/lib/vz/dump/` | 2 copies (managed by Proxmox) |
| External HDD | `KpihX-Backup/Homelab/Backups/Docker_Host/` | **2 most recent** |
| Google Drive | `Homelab/Backups/Docker_Host/` | **1 most recent** |
