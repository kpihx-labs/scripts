#!/bin/bash

cd "$(dirname "$0")"
source .env

# ==============================================================================
# 1. CONFIGURATION & AUTO-DÉTECTION
# ==============================================================================
TELEGRAM_TOKEN="$TELEGRAM_TOKEN"
CHAT_ID="$CHAT_ID"

# Cibles & Chemins
TARGET="8.8.8.8"
CT_ID="100"
PCT_CMD="/usr/sbin/pct"
PING_CMD="/usr/bin/ping"

# Fichiers d'état
STATE_DIR="/var/lib/homelab_watchdog"
LAST_IP_FILE="$STATE_DIR/last_ip"
LOG_FILE="/var/log/network_watchdog.log"
LOCK_FILE="/tmp/network_fixing.lock"

mkdir -p "$STATE_DIR"

# --- DÉTECTION DU MODE RÉSEAU (Le Cerveau) ---
# On regarde si wlo1 est configuré en DHCP dans le fichier interfaces actif
if grep -q "^iface wlo1 inet dhcp" /etc/network/interfaces; then
    MODE="WIFI"
    IF_WAN="wlo1"       # L'interface qui porte l'IP publique
    IF_PHY="wlo1"       # L'interface physique à reset
    WPA_CONF="/etc/wpa_supplicant/eduroam.conf"
    WPA_DRIVER="nl80211"
else
    MODE="WIRED"
    IF_WAN="vmbr0"      # Le bridge porte l'IP
    IF_PHY="nic1"       # La carte physique porte le lien
    WPA_CONF="/etc/wpa_supplicant/polytechnique.conf"
    WPA_DRIVER="wired"
fi

# ==============================================================================
# 2. FONCTIONS
# ==============================================================================

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$MODE] - $1" >> "$LOG_FILE"
}

send_telegram() {
    ICON="$1"
    TITLE="$2"
    MESSAGE="$3"
    if [ -z "$MESSAGE" ]; then MESSAGE="Notification système"; fi
    TEXT="$ICON **$TITLE ($MODE)** $ICON%0A%0A$MESSAGE"
    
    curl -s --max-time 10 -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$TEXT" > /dev/null
}

get_current_ip() {
    ip -4 addr show "$IF_WAN" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1
}

# ==============================================================================
# 3. VERROU ANTI-DOUBLON
# ==============================================================================
if [ -f "$LOCK_FILE" ]; then
    # Si le verrou a plus de 15 minutes, on le casse
    if [ $(find "$LOCK_FILE" -mmin +15) ]; then
        log "⚠️ Verrou expiré supprimé."
        rm "$LOCK_FILE"
    else
        # Une réparation est déjà en cours, on ne fait rien
        exit 0
    fi
fi

# ==============================================================================
# 4. HÔTE : VÉRIFICATION INTERNET
# ==============================================================================

HOST_OK=false
# Test de connectivité simple
if $PING_CMD -c 1 -W 5 "$TARGET" > /dev/null 2>&1; then
    HOST_OK=true
else
    # --- DÉBUT DU PROTOCOLE DE RÉPARATION ---
    touch "$LOCK_FILE"
    log "🔻 Hôte déconnecté sur $IF_WAN. Début réparation..."

    # Fix AppArmor (Spécifique à ton système FrankenDebian)
    if [ -f /etc/apparmor.d/sbin.dhclient ]; then
    	ln -sf /etc/apparmor.d/sbin.dhclient /etc/apparmor.d/disable/
    	apparmor_parser -R /etc/apparmor.d/sbin.dhclient 2>/dev/null || true
    fi

    # Nettoyage processus fantômes
    killall dhclient 2>/dev/null || true
    killall wpa_supplicant 2>/dev/null || true

    # --- ACTION 0 : Cycle Interface (Soft) ---
    log "Action 0: Cycle interfaces $IF_PHY..."
    ip link set "$IF_WAN" down 2>/dev/null
    ip link set "$IF_PHY" down
    sleep 2
    ip link set "$IF_PHY" up
    sleep 2
    # En wired, on remonte aussi le bridge
    if [ "$MODE" == "WIRED" ]; then ip link set "$IF_WAN" up; fi
    sleep 5

    if $PING_CMD -c 1 "$TARGET" > /dev/null 2>&1; then
        log "✅ Hôte réparé (Action 0)"
        send_telegram "✅" "RÉSEAU RÉTABLI" "Simple réveil d'interface."
        HOST_OK=true
    else
        # --- ACTION 1 : WPA Supplicant + DHCP (Hard) ---
        log "Action 1: Relance WPA ($WPA_DRIVER) & DHCP..."
        
        # Lancement WPA avec les bons paramètres dynamiques
        wpa_supplicant -B -i "$IF_PHY" -c "$WPA_CONF" -D "$WPA_DRIVER"
        
        # Attente plus longue en Wi-Fi pour l'association
        if [ "$MODE" == "WIFI" ]; then sleep 20; else sleep 15; fi
        
        # Demande IP
        dhclient -v "$IF_WAN" > /dev/null 2>&1
        sleep 7

        if $PING_CMD -c 1 "$TARGET" > /dev/null 2>&1; then
            HOST_OK=true
            log "✅ Hôte réparé (Action 1)"
            send_telegram "🛡️" "RÉSEAU RÉTABLI" "Relance WPA/DHCP réussie."
        else
            # --- ACTION 2 : Restart Systemd (Nuclear) ---
            log "Action 2: Restart system networking..."
            
            killall wpa_supplicant 2>/dev/null || true
            killall dhclient 2>/dev/null || true
            
            systemctl restart networking
            sleep 20 # Le wifi met du temps à revenir

            if $PING_CMD -c 1 "$TARGET" > /dev/null 2>&1; then
                log "✅ Hôte réparé (Action 2)"
                send_telegram "☢️" "RÉSEAU RÉTABLI" "Restart service networking complet."
                HOST_OK=true
            fi
        fi
    fi
    rm "$LOCK_FILE"
fi

if [ "$HOST_OK" = false ]; then
    log "❌ Échec total réparation Hôte."
    exit 1
fi

# --- Suivi IP (Notification en cas de changement) ---
CURRENT_IP=$(get_current_ip)
if [ -f "$LAST_IP_FILE" ]; then LAST_IP=$(cat "$LAST_IP_FILE"); else LAST_IP="Inconnue"; fi

if [ -n "$CURRENT_IP" ] && [ "$CURRENT_IP" != "$LAST_IP" ]; then
    echo "$CURRENT_IP" > "$LAST_IP_FILE"
    # On ignore les IP privées Docker ou vides
    if [[ "$CURRENT_IP" != 192.168* ]] && [[ "$CURRENT_IP" != 10.* ]]; then
        send_telegram "🔄" "NOUVELLE IP" "Interface $IF_WAN : \`$CURRENT_IP\`"
    fi
fi

# ==============================================================================
# 5. CONTENEUR : VÉRIFICATION PROFONDE
# ==============================================================================

# A. Le conteneur tourne-t-il ?
CT_STATUS=$($PCT_CMD status $CT_ID)

if [[ $CT_STATUS != *"running"* ]]; then
    log "⚠️ Conteneur $CT_ID éteint. Redémarrage..."
    $PCT_CMD start $CT_ID
    sleep 15
fi

# B. Le conteneur a-t-il internet ?
if ! $PCT_CMD exec $CT_ID -- ping -c 1 "$TARGET" > /dev/null 2>&1; then
    touch "$LOCK_FILE"
    log "🟠 Hôte OK mais Conteneur $CT_ID déconnecté."
    
    # En mode Wi-Fi, le NAT est géré par IPTables, on vérifie vmbr1
    ip link set vmbr1 up
    
    # Redémarrage du conteneur pour forcer la reprise du réseau
    $PCT_CMD stop $CT_ID
    sleep 5
    $PCT_CMD start $CT_ID
    sleep 20
    
    if $PCT_CMD exec $CT_ID -- ping -c 1 "$TARGET" > /dev/null 2>&1; then
        log "✅ Conteneur reconnecté."
        send_telegram "🐳" "CONTENEUR RÉTABLI" "Le Docker-Host a retrouvé internet."
    else
        log "❌ Échec réparation Conteneur."
    fi
    rm "$LOCK_FILE"
fi

exit 0
