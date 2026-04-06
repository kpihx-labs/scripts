# 🏗️ Proxmox Infrastructure (kpihx-labs)

Centralized automation suite for the Proxmox Hypervisor node `kpihx-labs`. This is the **Source of Truth** for the PVE environment. This entire folder is deployed to `/root/proxmox/` on the host.

---

## 📜 Contents Overview

| Script / Dir | Role | Schedule |
| :--- | :--- | :--- |
| `backup_docker_host/vzdump-hook.sh` | Auto cloud sync after every vzdump job | Sat 03:00 (via Proxmox job) |
| `backup_docker_host/backup_docker_host_server.sh` | Manual cloud push of latest local archive | Manual |
| `backup_docker_host/backup_docker_host_local.sh` | Mirror PVE dumps to local HDD from your PC | Manual |
| `backup_docker_host/restore_docker_host.sh` | Disaster recovery — pull archive from Cloud to PVE | Manual |
| `backup_docker_host/vzdump.conf` | Proxmox system config — registers the hook | Static |
| `network/network_watchdog.sh` | Internet self-repair watchdog | Every 4 minutes |
| `network/boot_notify.sh` | Telegram notification on server boot | On every reboot |
| `network/network_switch.sh` | Switch between WIFI and WIRED modes | Manual |
| `network/setup_eduroam.sh` | Install Eduroam WPA supplicant config | Manual |
| `maintenance.sh` | Full system update + Docker prune + reboot | Sat 04:00 |
| `lib/notifier.sh` | Shared Telegram notification library | (Library) |

➡️ **See sub-READMEs for full script-by-script documentation:**
- [Backups & Disaster Recovery](./backup_docker_host/README.md)
- [Network Management](./network/README.md)

---

## 📅 Full Scheduling Summary

| Task | Schedule | Trigger | Script |
| :--- | :--- | :--- | :--- |
| LXC 100 snapshot backup | **Sat 03:00** | Proxmox WebUI job | Native Proxmox |
| Cloud sync of backup | **After Sat 03:00 job** | `vzdump-hook.sh` auto-called | `backup_docker_host/vzdump-hook.sh` |
| System maintenance + reboot | **Sat 04:00** | `cron` | `maintenance.sh` |
| Network watchdog | **Every 4 minutes** | `cron` | `network/network_watchdog.sh` |
| Boot notification | **On every reboot** | `cron @reboot` | `network/boot_notify.sh` |

**Crontab entries on `kpihx-labs`:**
```cron
*/4 * * * * /root/proxmox/network/network_watchdog.sh >> /var/log/cron_watchdog_debug.log 2>&1
0 4 * * 6 /root/proxmox/maintenance.sh
@reboot /root/proxmox/network/boot_notify.sh >> /var/log/boot_notify_debug.log 2>&1
```

---

## ⚙️ Full Deployment Procedure (Fresh Node)

### Step 1: Copy the folder to the host
```bash
# From your local machine, via tmp/ because root SSH by key is blocked
rsync -avzL --delete sh/proxmox/ ivann@kpihx-labs:/tmp/proxmox/
ssh -t kpihx-labs "sudo rm -rf /root/proxmox && sudo mv /tmp/proxmox /root/proxmox && sudo chown -R root:root /root/proxmox && sudo chmod +x /root/proxmox/backup_docker_host/*.sh /root/proxmox/network/*.sh /root/proxmox/maintenance.sh"
```

### Step 2: Configure the environment file
```bash
ssh -t kpihx-labs "sudo cp /root/proxmox/.env.example /root/proxmox/.env && sudo nano /root/proxmox/.env"
```
Fill in:
```env
TELEGRAM_HOMELAB_TOKEN=<your-bot-token>
CHAT_ID=<your-chat-id>
```

### Step 3: Apply the vzdump hook configuration
```bash
ssh -t kpihx-labs "sudo cp /root/proxmox/backup_docker_host/vzdump.conf /etc/vzdump.conf"
```

### Step 4: Set up the crontab
```bash
ssh -t kpihx-labs "sudo crontab -e"
```
Paste:
```cron
*/4 * * * * /root/proxmox/network/network_watchdog.sh >> /var/log/cron_watchdog_debug.log 2>&1
0 4 * * 6 /root/proxmox/maintenance.sh
@reboot /root/proxmox/network/boot_notify.sh >> /var/log/boot_notify_debug.log 2>&1
```

### Step 5: Configure rclone for the root user
```bash
ssh -t kpihx-labs "sudo rclone config"
# Create remote named: gdrive-x
# Type: drive
# Follow OAuth prompts
```

### Step 6: Validate installation
```bash
# Test watchdog manually
ssh -t kpihx-labs "sudo /root/proxmox/network/network_watchdog.sh"

# Test Telegram notifications
ssh -t kpihx-labs "sudo /root/proxmox/network/boot_notify.sh"

# Test maintenance (will reboot the server)
ssh -t kpihx-labs "sudo /root/proxmox/maintenance.sh"
```

---

## 🧹 Purging Legacy Deployment Debris

If migrating from an older installation that placed files in `/usr/local/`:
```bash
ssh -t kpihx-labs "sudo rm -rf /root/scripts /home/ivann/scripts /usr/local/lib/homelab.sh /usr/local/bin/vzdump-hook.sh /etc/homelab.env"
```

---

## 🗂️ Log Reference

| Log File | Source |
| :--- | :--- |
| `/var/log/network_watchdog.log` | Watchdog events and repairs |
| `/var/log/cron_watchdog_debug.log` | Watchdog cron stderr |
| `/var/log/boot_notify.log` | Boot notification status |
| `/var/log/boot_notify_debug.log` | Boot notify cron stderr |
| `/var/log/maintenance.log` | apt/docker maintenance output |
| `/var/log/vzdump-rclone.log` | Cloud backup (hook + server push) |

---

*Maintained at `/root/proxmox/` on `kpihx-labs`. Local source: `sh/proxmox/` in this repository.*
