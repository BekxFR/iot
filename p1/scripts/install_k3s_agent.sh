#!/bin/bash
# K3s en mode agent (worker) sur la seconde machine.
set -e

NODE_IP="${NODE_IP:-192.168.56.111}"
SERVER_IP="${SERVER_IP:-192.168.56.110}"
TOKEN_FILE="/vagrant/confs/node-token"

echo "=== Installation K3s agent (mode agent) - P1 ==="

IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
if [ -z "$IFACE" ]; then
    echo "[FAIL] Aucune interface ne porte l'IP $NODE_IP"
    ip -o -4 addr show
    exit 1
fi
echo "Interface reseau dediee : $IFACE ($NODE_IP)"

apt-get update -y

if command -v ufw >/dev/null 2>&1; then
    ufw allow 22/tcp || true
fi

# Token publie par le serveur dans le dossier synchronise.
echo "Recuperation du token de jonction..."
for i in $(seq 1 60); do
    if [ -s "$TOKEN_FILE" ]; then
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[FAIL] Token introuvable dans $TOKEN_FILE"
        echo "       Demarrez d'abord la machine server : vagrant up chillionS"
        exit 1
    fi
    echo "  ... attente de la publication du token ($i/60)"
    sleep 5
done
K3S_TOKEN=$(tr -d '\r\n' < "$TOKEN_FILE")
echo "[OK] Token recupere"

echo "Attente de l'API du serveur (https://$SERVER_IP:6443)..."
for i in $(seq 1 60); do
    if curl -sk --max-time 5 "https://$SERVER_IP:6443/ping" >/dev/null 2>&1; then
        echo "[OK] Serveur K3s joignable"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[FAIL] Le serveur K3s ne repond pas sur $SERVER_IP:6443"
        exit 1
    fi
    sleep 5
done

curl -sfL https://get.k3s.io | \
    K3S_URL="https://$SERVER_IP:6443" \
    K3S_TOKEN="$K3S_TOKEN" \
    sh -s - agent \
    --node-ip "$NODE_IP" \
    --flannel-iface "$IFACE"

echo "Attente du demarrage de l'agent..."
for i in $(seq 1 60); do
    if systemctl is-active --quiet k3s-agent; then
        echo "[OK] Service k3s-agent actif"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[FAIL] Le service k3s-agent n'a pas demarre"
        systemctl status k3s-agent --no-pager || true
        exit 1
    fi
    sleep 5
done

echo "[OK] K3s agent installe et connecte au cluster $SERVER_IP:6443"
echo "     Verification depuis le server : vagrant ssh chillionS -c 'kubectl get nodes -o wide'"
