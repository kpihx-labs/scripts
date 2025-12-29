#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================
TELEGRAM_TOKEN="8589111784:AAFV4UaVOo7-zXcn0df-KwNjKY3t7NhIAXw"
CHAT_ID="1397540599"
LOG_FILE="/var/log/maintenance.log"

# Proxy (Indispensable pour apt à l'X)
# export http_proxy=http://129.104.201.11:8080
# export https_proxy=http://129.104.201.11:8080

# ==============================================================================
# FONCTIONS
# ==============================================================================
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

send_telegram() {
    MSG="$1"
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="🧹 **MAINTENANCE HEBDOMADAIRE** 🧹%0A%0A$MSG" > /dev/null
}

# ==============================================================================
# DÉBUT DU TRAITEMENT
# ==============================================================================
log "Démarrage de la maintenance..."
send_telegram "Début de la maintenance automatique (Mises à jour + Nettoyage)..."

# 1. MISE À JOUR SYSTÈME (Debian/Proxmox)
log "Update & Upgrade APT..."
apt-get update >> "$LOG_FILE" 2>&1
apt-get dist-upgrade -y >> "$LOG_FILE" 2>&1
apt-get autoremove -y >> "$LOG_FILE" 2>&1
apt-get autoclean >> "$LOG_FILE" 2>&1

# 2. NETTOYAGE DOCKER (Dans le conteneur 100)
# On commande au conteneur docker-host de faire son ménage
log "Nettoyage Docker sur le conteneur 100..."
/usr/sbin/pct exec 100 -- docker system prune -a -f --volumes >> "$LOG_FILE" 2>&1

# 3. NOTIFICATION FINALE ET REBOOT
log "Maintenance terminée. Redémarrage..."
send_telegram "✅ Maintenance terminée.%0A🔄 Le serveur va redémarrer dans 1 minute."

# On attend un peu pour que le message Telegram parte
sleep 5

# Reboot
/sbin/reboot
