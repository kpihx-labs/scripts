# AGENTS.md — Homelab Administration Scripts

> Project context for all AI agents working in this repository.
> Loaded automatically by all KπX agents when present at project root.

## KπX Mantras

**Exploration:** Problem First → Why before How → Visualization
**Architecture:** 0 Trust · 100% Control | 0 Magic · 100% Transparency | 0 Hardcoding · 100% Flexibility

## Project Overview

| Field | Value |
|-------|-------|
| Purpose | A collection of personal shell scripts to automate the administration of the KpihX Homelab server. |
| Stack | Shell (Bash), rsync, rclone, curl |
| Status | 🟢 Active & Maintained |

## Architecture Rules

- **Modularity:** Each script is self-contained and focuses on a single task (backup, network, maintenance).
- **Configuration via Environment:** All secrets (API tokens, chat IDs) and machine-specific paths are managed via a `.env` file, sourced at the start of each script.
- **Robustness:** Scripts include error checking (e.g., SSH connection, command success) and provide detailed notifications.
- **Notifications:** Key operations send status updates (success, error, warning) to a Telegram chat for monitoring.
- **Client vs. Server:** A clear distinction is made between scripts running on the server (e.g., `network_watchdog.sh`) and scripts running on a client machine (e.g., `backup_homelab.sh`).
- **CI/CD for Mirroring:** The `.gitlab-ci.yml` is used exclusively to synchronize the repository to GitHub, not for deployment.

## Evolution Rules

- New script → Add a corresponding section to the main `README.md` explaining its purpose and usage.
- Any significant change to a script's logic → Update its documentation in the `README.md`.
- Changes to environment variables → Update `.env.example` to reflect the new keys.
- **Makefile is the standard task runner** — use `make push` (not raw `git push`).
