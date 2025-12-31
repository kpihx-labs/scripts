# Homelab Administration Scripts

A collection of personal shell scripts to automate the administration of my Homelab server.

## Overview

These scripts are designed to handle various automated tasks such as backups, system maintenance, and network monitoring. They are configured to send notifications via Telegram.

## Getting Started

### Prerequisites

Ensure you have the following tools installed on your system:

-   `rsync`
-   `rclone` (for cloud backups)
-   `curl` (for Telegram notifications)
-   `ssh` client
-   `notify-send` (optional, for desktop notifications)

### Installation

1.  **Clone the repository:**
    ```bash
    git clone <your-repo-url>
    cd sh
    ```

2.  **Set up environment variables:**
    Copy the example environment file and fill in your details.
    ```bash
    cp .env.example .env
    ```
    Now, edit `.env` with your favorite editor:
    ```ini
    # Telegram Bot Token from BotFather
    TELEGRAM_TOKEN="YOUR_TELEGRAM_TOKEN"

    # Your personal Telegram Chat ID
    CHAT_ID="YOUR_CHAT_ID"
    ```
    -   To get a `TELEGRAM_TOKEN`, create a new bot with `@BotFather` on Telegram.
    -   To find your `CHAT_ID`, you can message the `@userinfobot` on Telegram.

## Scripts

This repository is organized into three main categories of scripts.

---

## 🔌 Network Configuration

This group of scripts and configuration files manages the server's network connectivity, allowing dynamic switching between wired and Wi-Fi networks that require specific authentication methods.

### `network_switch.sh`

This is the main script for managing network connections. It dynamically changes the server's network configuration by modifying the `/etc/network/interfaces` file.

**Usage:**
```bash
sudo ./network_switch.sh [wifi|wired]
```

**Features:**
-   **`wifi` mode:** Activates the Wi-Fi connection (wlo1), configured for the Eduroam network. It uses the configuration defined in `interfaces/interfaces.wifi`. This setup also establishes a NAT for containers through the Wi-Fi interface.
-   **`wired` mode:** Activates the wired connection (nic1), configured for the university's network using 802.1X. It uses the configuration from `interfaces/interfaces.wired`.
-   Sends a Telegram notification to confirm the switch and displays the new IP address.
-   Creates a backup of the old `interfaces` file and can restore it if the network restart fails.

### Configuration Files

#### `interfaces/` directory
This directory holds the template files for `/etc/network/interfaces`:
-   `interfaces.wifi`: Defines the network setup for Wi-Fi (DHCP on `wlo1` with `wpa_supplicant`) and creates a NAT bridge for containers.
-   `interfaces.wired`: Defines the network setup for a wired 802.1X connection (on `nic1`) and bridges it for use by containers.

#### `network.conf.d/` directory
This directory contains the `wpa_supplicant` configurations needed for authentication:
-   `eduroam.conf`: Configuration for the `eduroam` Wi-Fi network (EAP-TTLS/PAP). It is used by `interfaces.wifi`.
-   `polytechnique.conf`: Configuration for the wired network of École Polytechnique, which uses 802.1X authentication. It is used by `interfaces.wired`.

### `setup_eduroam.sh`

A helper script to automate the configuration of the `eduroam.conf` file.

**Features:**
-   It runs the `eduroam-linux-Ecole_Polytechnique-Ecole_polytechnique.py` script.
-   It passes the user's credentials to the Python script to generate the WPA supplicant configuration.
-   It then installs the certificate and configuration file in the correct system locations.

**Underlying Script:**
-   `eduroam-linux-Ecole_Polytechnique-Ecole_polytechnique.py`: A standard script provided by the Eduroam CAT (Configuration Assistant Tool), tailored for École Polytechnique.

---

## 🛠️ System Administration & Monitoring

These scripts handle the server's routine maintenance, monitoring, and status notifications.

### `network_watchdog.sh`

A crucial script that constantly monitors the server's internet connection and attempts to automatically repair it if it fails.

**Features:**
-   **Dynamic Detection:** Automatically detects if the server is in `WIFI` or `WIRED` mode by inspecting `/etc/network/interfaces`.
-   **Host Monitoring:** Pings a reliable external target to check for connectivity.
-   **Automated Repair Sequence:** If the host is offline, it triggers a series of actions, from a simple interface reset to a full networking service restart. The actions are adapted to the current network mode (Wi-Fi or Wired).
-   **Container Monitoring:** If the host is online but a specific LXC container is not, it reboots the container.
-   **IP Change Notifications:** Sends a Telegram message when the server's public IP address changes.
-   **Locking:** Prevents multiple repair instances from running simultaneously.

### `maintenance.sh`

Performs weekly maintenance tasks on the server.

**Features:**
-   Sends start and end notifications via Telegram.
-   Updates all system packages using `apt-get`.
-   Cleans up old packages and caches.
-   Prunes the Docker system of a specified container to free up space.
-   Reboots the server after completion.

**Intended Usage:**
Designed to be run as a weekly `cron` job.

### `boot_notify.sh`

A simple script to notify you when the server has successfully booted up.

**Features:**
-   Waits for an active internet connection.
-   Sends a "Server Online" message via Telegram.

**Intended Usage:**
Designed to be run at boot time via a `@reboot` cron job or a systemd service.

---

## 💻 Client-Side Scripts

This category contains scripts that are meant to be run from a client machine, not on the server itself.

### `backup_homelab.sh`

This script manages the backup of Proxmox VE virtual machine dumps from a client machine (e.g., a laptop).

**Features:**
-   **Client-Side Execution:** Connects to the Proxmox server via SSH to access the backups.
-   **Multi-Destination Backup:**
    1.  **Local HDD:** Mirrors the remote backup directory (`/var/lib/vz/dump`) to a locally connected external hard drive using `rsync`. It also performs rotation, keeping only the two most recent backups.
    2.  **Cloud Storage:** Uploads the very latest backup from the local HDD to a cloud provider (configured with `rclone`).
-   **Cloud Cleanup:** Ensures only the single latest backup is kept in the cloud to save space.
-   **Rich Notifications:** Sends detailed success or failure messages to Telegram, including the size of the uploaded backup.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Created and maintained by KpihX.*
