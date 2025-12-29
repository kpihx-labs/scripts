# Homelab Administration Scripts

A collection of personal shell scripts to automate the administration of my Homelab server.

## Overview

These scripts are designed to handle various automated tasks such as backups, system maintenance, and network monitoring. They are configured to send notifications via Telegram.

## Getting Started

### Prerequisites

Ensure you have the following tools installed on your system:

-   `rclone` (for both server and cloud transfers)
-   `curl` (for Telegram notifications)
-   `ssh` client
-   `notify-send` (optional, for desktop notifications)

**On the remote server:**
-   `python3` (for the temporary HTTP server)

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

This section describes the available scripts. The configurations are done inside each script file.

---

### 📥 `backup_homelab.sh`

This script performs a multi-destination backup of Proxmox virtual machine dumps using an optimized `rclone` HTTP transfer method.

**Features:**
-   **HTTP Turbo Transfer**: Instead of SFTP, the script initiates a temporary `python3` web server on the remote Proxmox host via SSH.
-   **On-the-fly Rclone Remote**: It then uses an in-line `rclone` HTTP remote to download the files at high speed, without requiring any prior `rclone` configuration for the source.
-   **Automatic Cleanup**: The temporary web server on the remote host is automatically terminated after the transfer is complete.
-   **Local Rotation**: Keeps only the 2 most recent backup archives on the local HDD to save space.
-   **Cloud Sync**: Uploads the latest backup archive from the HDD to a cloud storage provider (e.g., Google Drive) using a standard, pre-configured `rclone` remote.
-   **Cloud Rotation**: Cleans the cloud directory, ensuring only the very last backup is stored.
-   **Notifications**: Sends a Telegram notification with the status (success or failure) and a summary.

**Dependencies:** `rclone`, `curl`, `notify-send`. The remote server must have `python3` installed.

---

### 🧹 `maintenance.sh`

A script for performing routine weekly maintenance on a Debian-based server (like Proxmox).

**Features:**
-   Sends a Telegram notification at the start and end of the maintenance.
-   Updates all system packages (`apt-get update`, `dist-upgrade`).
-   Cleans up unused packages and local caches (`autoremove`, `autoclean`).
-   Triggers a Docker system prune command on a specific container (`pct exec`) to free up disk space.
-   Reboots the server upon successful completion.

**Intended Usage:**
This script is designed to be run automatically, for example, via a weekly `cron` job.

---

### 🌐 `network_watchdog.sh`

A watchdog script to monitor and repair network connectivity for the host and a specific Proxmox container (LXC).

**Features:**
-   Periodically checks the host's internet connection by pinging a reliable target (`8.8.8.8`).
-   If the host is offline, it triggers a sequence of repair actions:
    1.  Restarts network interfaces.
    2.  Renews the DHCP lease.
    3.  Resets the `wpa_supplicant`.
    4.  Restarts the system networking service.
-   Checks the internet connectivity of a specified container. If the container is offline while the host is online, it reboots the container.
-   Sends Telegram notifications for status changes (network down, network repaired, container rebooted).
-   Tracks public IP address changes and sends a notification when a new IP is assigned.

**Intended Usage:**
This script is designed to be run at frequent intervals (e.g., every 5 minutes) via a `cron` job to ensure high availability.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Created and maintained by KpihX.*
