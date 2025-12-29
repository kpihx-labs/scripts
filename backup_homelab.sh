#!/bin/bash

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# --- TELEGRAM ---
TELEGRAM_TOKEN="8589111784:AAFV4UaVOo7-zXcn0df-KwNjKY3t7NhIAXw"
CHAT_ID="1397540599"

# --- SERVEUR (SOURCE) ---
SERVER_ALIAS="homelab"
REMOTE_DIR="/var/lib/vz/dump"

# --- HDD EXTERNE (DESTINATION 1) ---
HDD_MOUNT_POINT="/media/kpihx/KpihX-Backup"
HDD_DEST_DIR="$HDD_MOUNT_POINT/Backups_Homelab"

# --- CLOUD RCLONE (DESTINATION 2) ---
# Nom du remote configuré dans 'rclone config'
RCLONE_REMOTE="gdrive-full"
# Nom du dossier sur Google Drive
RCLONE_FOLDER="Backup_Homelab"
RCLONE_DEST="$RCLONE_REMOTE:$RCLONE_FOLDER"

NOW=$(date +"%Y-%m-%d %H:%M:%S")

# ==============================================================================
# FONCTIONS
# ==============================================================================

alert() {
    TYPE="$1"
    MESSAGE="$2"
    
    # Notification Bureau
    notify-send "Backup Homelab [$TYPE]" "$MESSAGE" 2>/dev/null
    
    case $TYPE in
        "SUCCESS") ICON="✅" ;;
        "ERROR")   ICON="❌" ;;
        "WARN")    ICON="⚠️" ;;
        *)         ICON="ℹ️" ;;
    esac
    
    # Notification Telegram
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$ICON **BACKUP** $ICON%0A%0A$MESSAGE" \
        -d parse_mode="Markdown" > /dev/null
}

check_ssh() {
    if ! ssh -q -o ConnectTimeout=5 $SERVER_ALIAS exit; then
        alert "ERROR" "Serveur injoignable via SSH."
        exit 1
    fi
}

mount_hdd_if_needed() {
    if [ ! -d "$HDD_MOUNT_POINT" ]; then
        alert "ERROR" "HDD non monté à : $HDD_MOUNT_POINT"
        exit 1
    fi
    mkdir -p "$HDD_DEST_DIR"
}

# ==============================================================================
# EXÉCUTION
# ==============================================================================

echo "[$NOW] 🚀 Démarrage Backup..."
check_ssh
mount_hdd_if_needed

# ---------------------------------------------------------
# PHASE 1 : HDD (MIROIR DU SERVEUR VIA SSH)
# ---------------------------------------------------------
echo -e "\n--- 1. Synchronisation HDD ---"

# On récupère les fichiers depuis le serveur vers le HDD local
# Changements :
# -c aes128-gcm@openssh.com : Algorithme de chiffrement le plus rapide (accélération matérielle)
# --whole-file : On ne calcule pas les deltas (inutile sur des archives compressées), on envoie tout direct.
# --inplace : Écrit directement sur le fichier de destination (évite la copie temporaire)

rsync -av --progress --partial --size-only --inplace --whole-file \
    -e "ssh -T -c aes128-gcm@openssh.com -o Compression=no -o ServerAliveInterval=60 -o ServerAliveCountMax=10 -o ConnectTimeout=10" \
    --exclude '*.log' \
    --exclude '*.notes' \
    $SERVER_ALIAS:$REMOTE_DIR/ "$HDD_DEST_DIR/"

if [ $? -ne 0 ]; then
    alert "ERROR" "Échec du téléchargement rsync vers HDD."
    exit 1
fi

echo -e "\n--- 2. Rotation HDD (Garder les 2 récents) ---"
cd "$HDD_DEST_DIR" || exit 1

ARCHIVES=$(ls -1t *.zst *.vma *.tar.gz 2>/dev/null)
COUNT=0
KEEP=2

echo "$ARCHIVES" | while read -r ARCHIVE_FILE; do
    [ -z "$ARCHIVE_FILE" ] && continue
    COUNT=$((COUNT+1))

    if [ "$COUNT" -gt "$KEEP" ]; then
        echo "🗑️ Suppression vieux backup HDD : $ARCHIVE_FILE"
        rm -f "$ARCHIVE_FILE"
    fi
done

# ---------------------------------------------------------
# PHASE 2 : CLOUD (RCLONE - UPLOAD DIRECT)
# ---------------------------------------------------------
echo -e "\n--- 3. Sync Google Drive (Rclone) ---"

# On prend la dernière archive présente sur le HDD
LATEST_ARCHIVE=$(ls -t "$HDD_DEST_DIR"/*.zst "$HDD_DEST_DIR"/*.vma "$HDD_DEST_DIR"/*.tar.gz 2>/dev/null | head -n 1)

if [ -z "$LATEST_ARCHIVE" ]; then
    alert "WARN" "Aucune archive trouvée sur le HDD pour le Cloud."
else
    ARCHIVE_NAME=$(basename "$LATEST_ARCHIVE")

    echo "📂 Fichier à traiter : $ARCHIVE_NAME"
    echo "📤 Upload vers $RCLONE_DEST..."

    # Upload optimisé :
    # --transfers=4 : Envoie plusieurs morceaux en parallèle
    # --drive-chunk-size=32M : Optimise la vitesse pour Google Drive
    # --bwlimit 5M : Limite à 5Mo/s pour ne pas tuer la connexion du PC (optionnel)
    rclone copy "$LATEST_ARCHIVE" "$RCLONE_DEST" \
        --transfers=4 \
        --drive-chunk-size=32M \
        --stats-one-line -v

    if [ $? -eq 0 ]; then
        echo "✅ Upload réussi."
        
        # Nettoyage Cloud : On supprime tout ce qui n'est pas le fichier actuel
        echo "🧹 Nettoyage Cloud (Garder uniquement le dernier fichier)..."
        
        # lsf liste les fichiers distants. grep -v exclut le fichier actuel.
        rclone lsf "$RCLONE_DEST" --files-only | grep -v "$ARCHIVE_NAME" | while read -r FILE_TO_DELETE; do
            echo "🗑️ Suppression distant : $FILE_TO_DELETE"
            rclone deletefile "$RCLONE_DEST/$FILE_TO_DELETE"
        done
        
        SIZE=$(du -sh "$LATEST_ARCHIVE" | cut -f1)
        alert "SUCCESS" "Backup terminé !%0AHDD : OK (Miroir)%0ACloud : Uploadé ($SIZE)"
    else
        alert "ERROR" "Erreur upload Rclone vers Google Drive."
    fi
fi

echo -e "\n🏁 Terminé."
