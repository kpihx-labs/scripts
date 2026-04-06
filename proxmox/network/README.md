# 🌐 Proxmox Network Management

This module manages the connectivity of the hypervisor node (`kpihx-labs`) — including internet watchdog, boot notifications, and dynamic WIFI/WIRED switching.

---

## 📜 Script Manifest

### 1. `network_watchdog.sh` — Autonomous Internet Watchdog
| | |
| :--- | :--- |
| **Deployed at** | `/root/proxmox/network/network_watchdog.sh` |
| **Schedule** | **Every 4 minutes** via cron: `*/4 * * * * /root/proxmox/network/network_watchdog.sh` |
| **Logs** | `/var/log/network_watchdog.log` (also `/var/log/cron_watchdog_debug.log` for cron stderr) |
| **What it does** | Ping `8.8.8.8`. If the host has no internet, triggers a 3-step self-repair protocol. Also monitors LXC 100 container connectivity. Tracks IP changes and sends a notification on every IP change |
| **Notifications** | Telegram (SUCCESS on each repair, WARN for aggressive repair, INFO on IP change) |

**Repair protocol steps:**
1. **Action 0 (Soft)**: Cycles the physical interface down+up (`nic1` or `wlo1`)
2. **Action 1 (Hard)**: Restarts `wpa_supplicant` + `dhclient`
3. **Action 2 (Nuclear)**: Restarts the full `networking` systemd service

**Dual-mode detection**: The script auto-detects if the server is in `WIFI` mode (`wlo1` via DHCP) or `WIRED` mode (`vmbr0` / `nic1`) by reading `/etc/network/interfaces` and adapts all repair actions accordingly.

### 2. `boot_notify.sh` — Startup Telegram Alert
| | |
| :--- | :--- |
| **Deployed at** | `/root/proxmox/network/boot_notify.sh` |
| **Schedule** | **On every system reboot** via cron: `@reboot /root/proxmox/network/boot_notify.sh` |
| **Logs** | `/var/log/boot_notify.log` (also `/var/log/boot_notify_debug.log` for cron stderr) |
| **What it does** | Waits up to 5 minutes for the network to come online (pings `google.com` every 5 seconds), then sends a Telegram `🚀 SERVEUR EN LIGNE` confirmation message |
| **Notifications** | Telegram (SUCCESS once online) |

### 3. `network_switch.sh` — Dynamic WIFI / WIRED Switcher
| | |
| :--- | :--- |
| **Deployed at** | `/root/proxmox/network/network_switch.sh` |
| **Trigger** | **Manual only** |
| **Usage** | `sudo /root/proxmox/network/network_switch.sh wifi` or `sudo /root/proxmox/network/network_switch.sh wired` |
| **What it does** | Replaces `/etc/network/interfaces` with the appropriate template (from `interfaces/`). Backs up the current config before switching. Reloads networking. Manages `vmbr1` bridge for NAT routing to LXC containers |
| **Templates** | `interfaces/interfaces.wifi` and `interfaces/interfaces.wired` |

### 4. `setup_eduroam.sh` — Eduroam WPA Supplicant Configurator
| | |
| :--- | :--- |
| **Deployed at** | `/root/proxmox/network/setup_eduroam.sh` |
| **Trigger** | **Manual only** (when connecting to Eduroam at École Polytechnique) |
| **What it does** | Runs the official Eduroam CAT Python installer tool (`eduroam-linux-*.py`) and installs the `eduroam.conf` WPA supplicant config correctly |
| **Dependencies** | `python3`, the bundled `eduroam-linux-*.py` file |

---

## 📁 Directory Contents

| File / Directory | Purpose |
| :--- | :--- |
| `network_watchdog.sh` | Autonomous 4-min internet watchdog |
| `boot_notify.sh` | Boot startup Telegram notification |
| `network_switch.sh` | Dynamic WIFI/WIRED interface switcher |
| `setup_eduroam.sh` | Eduroam WPA config installer |
| `eduroam-linux-*.py` | Official Eduroam CAT installer for Polytechnique |
| `interfaces/interfaces.wifi` | Template for WIFI mode (`wlo1` DHCP) |
| `interfaces/interfaces.wired` | Template for WIRED mode (`nic1` 802.1X) |
| `network.conf.d/eduroam.conf` | WPA supplicant config — Eduroam (wifi) |
| `network.conf.d/polytechnique.conf` | WPA supplicant config — Polytechnique (wired) |

---

## ⚙️ Setup Procedure (First Deploy or Fresh Node)

1. **Deploy the scripts** (from local machine):
   ```bash
   rsync -avzL --delete sh/proxmox/ ivann@kpihx-labs:/tmp/proxmox/
   ssh -t kpihx-labs "sudo mv /tmp/proxmox /root/proxmox && sudo chown -R root:root /root/proxmox && sudo chmod +x /root/proxmox/network/*.sh"
   ```

2. **Configure the crontab**:
   ```bash
   ssh -t kpihx-labs "sudo crontab -e"
   ```
   Add these lines:
   ```cron
   */4 * * * * /root/proxmox/network/network_watchdog.sh >> /var/log/cron_watchdog_debug.log 2>&1
   @reboot /root/proxmox/network/boot_notify.sh >> /var/log/boot_notify_debug.log 2>&1
   ```

3. **Configure the `.env`**:
   ```bash
   ssh -t kpihx-labs "sudo nano /root/proxmox/.env"
   # Required:
   # TELEGRAM_HOMELAB_TOKEN=<bot-token>
   # CHAT_ID=<your-chat-id>
   ```

4. **To enable WIFI (Eduroam) mode**:
   ```bash
   sudo /root/proxmox/network/setup_eduroam.sh
   sudo /root/proxmox/network/network_switch.sh wifi
   ```

5. **To enable WIRED (Polytechnique) mode**:
   ```bash
   sudo /root/proxmox/network/network_switch.sh wired
   ```

---

## 📅 Scheduling Summary

| Task | Schedule | Trigger | Script |
| :--- | :--- | :--- | :--- |
| Network watchdog | **Every 4 minutes** | cron | `network_watchdog.sh` |
| Boot notification | **On every reboot** | cron (`@reboot`) | `boot_notify.sh` |
| WIFI/WIRED switch | **Manual** | Admin | `network_switch.sh` |
| Eduroam setup | **Manual** | Admin | `setup_eduroam.sh` |

---

## 🗂️ Log Reference

| Log File | Script | Content |
| :--- | :--- | :--- |
| `/var/log/network_watchdog.log` | `network_watchdog.sh` | All repair events, IP changes |
| `/var/log/cron_watchdog_debug.log` | cron wrapper | Stderr from cron execution |
| `/var/log/boot_notify.log` | `boot_notify.sh` | Network wait status and send result |
| `/var/log/boot_notify_debug.log` | cron wrapper | Stderr from cron execution |
