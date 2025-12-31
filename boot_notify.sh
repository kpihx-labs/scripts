#!/bin/bash

# On se place dans le dossier du script
cd "$(dirname "$0")" || exit 1

source .env

# ==============================================================================
# 1. CONFIGURATION & AUTO-DÉTECTION
# ==============================================================================
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"
CHAT_ID="$CHAT_ID"
LOG_FILE="/var/log/boot_notify.log"

echo "$(date) - Démarrage du script de notification..." >> "$LOG_FILE"

# Boucle d'attente réseau (Max 60 essais de 5s = 5 minutes)
MAX_RETRIES=60
COUNT=0

# On attend que le réseau se mette en place
sleep 10
while ! ping -c 1 -W 2 google.com > /dev/null 2>&1; do
    echo "$(date) - Pas de réseau, attente..." >> "$LOG_FILE"
    sleep 5
    COUNT=$((COUNT+1))
    if [ $COUNT -ge $MAX_RETRIES ]; then
        echo "$(date) - Abandon : Pas de réseau après 5 minutes." >> "$LOG_FILE"
        exit 1
    fi
done

echo "$(date) - Réseau OK. Envoi Telegram..." >> "$LOG_FILE"

# Envoi du message
/usr/bin/curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
    -d chat_id="$CHAT_ID" \
    -d text="🚀 **SERVEUR EN LIGNE**%0AJe suis redémarré et connecté !" >> "$LOG_FILE" 2>&1

echo "$(date) - Terminé." >> "$LOG_FILE"
