# CHANGELOG — Homelab Administration Scripts

## [Phoenix v3.1] - 2026-04-06

### Added
- **hsh dispatcher**: Universal script at root for orchestrating local tasks (backup, status, maintenance).
- **Makefile install**: New target to symlink `hsh` to `~/.local/bin/hsh`.
- **AGENTS.md symlink**: Root pointer to `.agents/AGENTS.md` for AI context.
- **restore_docker_host.sh**: Cloud restoration script for the hypervisor node.

### Changed
- **Modular Repositories**: Scripts reorganized into node-specific folders (`proxmox/` and `docker_host/`).
- **Path Standardization**: All scripts use `$HOME` and relative paths (via `BASH_SOURCE[0]`).
- **Log Centralization**: All crontab entries redirected to `/var/log/*.log` with clear labels.
- **README Overhaul**: Exhaustive "Copy-and-Run" instructions for all modules.

### Security
- **Deterministic Key Derivation**: Vault local backups now derive encryption keys live from Bitwarden Master Password.
- **Server Secret Isolation**: Server-side backups use `/root/.vault_secret` (chmod 400).
- **Zero-Trust Notifications**: Notifications decoupled from hardcoded paths; use library in `proxmox/lib/` or `docker_host/lib/`.
