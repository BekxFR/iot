#!/bin/bash
# K3s en mode controller (server) sur la premiere machine.
set -e

NODE_IP="${NODE_IP:-192.168.56.110}"
TOKEN_FILE="/vagrant/confs/node-token"

echo "=== Installation K3s server (mode controller) - P1 ==="

# L'interface dediee est detectee a partir de l'IP : le script reste valide
# quel que soit le nommage des interfaces de la box (enp0s8, eth1, ...).
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
if [ -z "$IFACE" ]; then
    echo "[FAIL] Aucune interface ne porte l'IP $NODE_IP"
    ip -o -4 addr show
    exit 1
fi
echo "Interface reseau dediee : $IFACE ($NODE_IP)"

apt-get update -y

if command -v ufw >/dev/null 2>&1; then
    ufw allow 22/tcp   || true
    ufw allow 6443/tcp || true
fi

# L'installeur K3s fournit egalement kubectl (/usr/local/bin/kubectl).
curl -sfL https://get.k3s.io | sh -s - server \
    --node-ip "$NODE_IP" \
    --flannel-iface "$IFACE"

echo "Attente de l'API Kubernetes..."
for i in $(seq 1 60); do
    if k3s kubectl get nodes >/dev/null 2>&1; then
        echo "[OK] API Kubernetes disponible"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[FAIL] L'API K3s ne repond pas"
        systemctl status k3s --no-pager || true
        exit 1
    fi
    sleep 5
done

# kubeconfig utilisable par l'utilisateur vagrant, pointant sur l'IP dediee.
install -d -o vagrant -g vagrant -m 700 /home/vagrant/.kube
sed "s/127.0.0.1/$NODE_IP/g" /etc/rancher/k3s/k3s.yaml > /home/vagrant/.kube/config
chown vagrant:vagrant /home/vagrant/.kube/config
chmod 600 /home/vagrant/.kube/config

if ! grep -q 'KUBECONFIG' /home/vagrant/.bashrc; then
    cat >> /home/vagrant/.bashrc <<'EOF'
export KUBECONFIG=/home/vagrant/.kube/config
alias k=kubectl
EOF
fi

# Publication du token de jonction pour l'agent, via le dossier synchronise.
if [ ! -d /vagrant ]; then
    echo "[FAIL] Dossier synchronise /vagrant absent : impossible de publier le token"
    exit 1
fi
mkdir -p "$(dirname "$TOKEN_FILE")"
cp /var/lib/rancher/k3s/server/node-token "$TOKEN_FILE"
echo "[OK] Token de jonction publie dans $TOKEN_FILE"

echo "[OK] K3s server installe (controller) - API sur https://$NODE_IP:6443"
KUBECONFIG=/etc/rancher/k3s/k3s.yaml kubectl get nodes -o wide
