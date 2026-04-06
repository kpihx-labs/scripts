# 🐳 Docker Host Automation (docker-host)

This module contains all automation scripts for `docker-host` (LXC 100 on Proxmox). The entire folder is deployed to `/root/docker_host/` on the container.

---

## 📜 Contents Overview

| Script / Dir | Role | Schedule |
| :--- | :--- | :--- |
| `backup_vault/backup_vault_server.sh` | Automated encrypted Vaultwarden backup to Cloud | **Sun 02:00** |
| `backup_vault/backup_vault_local.sh` | Manual local backup (PC → HDD + Cloud) | Manual |
| `backup_vault/restore_vault.sh` | Disaster recovery from Cloud | Manual |
| `lib/gen_encrypt_key.sh` | One-time key derivation tool (setup only) | Once |
| `lib/notifier.sh` | Shared Telegram notification library | (Library) |

➡️ **See sub-README for full Vault documentation:**
- [Vault Backup & Recovery](./backup_vault/README.md)

---

## 📅 Full Scheduling Summary

| Task | Schedule | Trigger | Script |
| :--- | :--- | :--- | :--- |
| Vaultwarden encrypted cloud backup | **Sun 02:00** | cron on `docker-host` | `backup_vault/backup_vault_server.sh` |
| Manual local + cloud backup | **Manual** | from PC | `backup_vault/backup_vault_local.sh` |
| Disaster recovery | **Manual** | on `docker-host` | `backup_vault/restore_vault.sh` |

**Crontab on `docker-host` (root crontab):**
```cron
0 2 * * 0 /root/docker_host/backup_vault/backup_vault_server.sh >> /var/log/vault-backup.log 2>&1
```

---

## ⚙️ Full Deployment Procedure (Fresh Container)

### Step 1: Copy the folder to docker-host
```bash
# From your local machine
scp -r sh/docker_host/ root@docker-host:/root/docker_host/
ssh docker-host "chmod +x /root/docker_host/backup_vault/*.sh /root/docker_host/lib/*.sh"
```

### Step 2: Configure the environment file
```bash
ssh docker-host "cp /root/docker_host/.env.example /root/docker_host/.env && nano /root/docker_host/.env"
```
Required variables:
```env
TELEGRAM_HOMELAB_TOKEN=<your-bot-token>
CHAT_ID=<your-telegram-chat-id>
```

### Step 3: Configure rclone for root
```bash
ssh docker-host "rclone config"
# Create remote named: gdrive-x (type: drive, OAuth as root)
```

### Step 4: Initialise the vault encryption key
```bash
# On docker-host: derive and store the key
ssh docker-host "/root/docker_host/lib/gen_encrypt_key.sh"
# Copy the displayed 64-char hex key, then:
ssh docker-host "echo '<paste-key-here>' > /root/.vault_secret && chmod 400 /root/.vault_secret"
```

### Step 5: Configure the crontab
```bash
ssh docker-host "crontab -e"
```
Paste:
```cron
0 2 * * 0 /root/docker_host/backup_vault/backup_vault_server.sh >> /var/log/vault-backup.log 2>&1
```

### Step 6: Validate the installation
```bash
# Run a live test (sends Telegram notification + uploads to Cloud)
ssh docker-host "/root/docker_host/backup_vault/backup_vault_server.sh"
# Check the Cloud
rclone lsf gdrive-x:Homelab/Backups/Vault --files-only | sort -r
```

---

## 🧹 Purging Legacy Deployment Debris

If migrating from an older installation:
```bash
ssh docker-host "rm -f /usr/local/lib/homelab.sh /usr/local/bin/vault-backup.sh /etc/homelab.env"
```

---

## 🗂️ Log Reference

| Log File | Source |
| :--- | :--- |
| `/var/log/vault-backup.log` | `backup_vault_server.sh` automated + manual execution |

---

## 🔐 Security Model

- The server-side automation uses `/root/.vault_secret` (file permissions: `400 root:root`) created by `gen_encrypt_key.sh`.
- Local and restore scripts **never store the key** — it is derived live from your Bitwarden Master Password using `SHA-256 + static salt` and immediately wiped from memory with `unset` after use.
- All archive files transmitted to Cloud are GPG AES-256 encrypted before leaving the server.

---

*Maintained at `/root/docker_host/` on `docker-host`. Local source: `sh/docker_host/` in this repository.*
