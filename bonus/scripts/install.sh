#!/bin/bash

echo "=== Installation des outils pour le Bonus - GitLab local ==="

# Verification des outils de base (installes par P3)
echo "Verification des outils de base..."

# Docker
if ! command -v docker >/dev/null 2>&1; then
    echo "Docker non trouve, installation via le script P3..."
    cd "$(dirname "$0")/../../p3" && ./scripts/install.sh
    cd "$(dirname "$0")/.."
    echo "Redemarrez votre session ou utilisez 'newgrp docker' puis relancez."
    exit 1
fi
echo "[OK] Docker : $(docker --version)"

# kubectl
if ! command -v kubectl >/dev/null 2>&1; then
    echo "Installation de kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi
echo "[OK] kubectl : $(kubectl version --client -o yaml 2>/dev/null | awk '/gitVersion/ {print $2; exit}')"

# k3d
if ! command -v k3d >/dev/null 2>&1; then
    echo "Installation de k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi
echo "[OK] k3d : $(k3d --version)"

# Argo CD CLI
if ! command -v argocd >/dev/null 2>&1; then
    echo "Installation d'Argo CD CLI..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    chmod +x argocd-linux-amd64
    sudo mv argocd-linux-amd64 /usr/local/bin/argocd
fi
echo "[OK] Argo CD CLI : $(argocd version --client --short 2>/dev/null || echo 'installe')"

# Helm (specifique au bonus)
if ! command -v helm >/dev/null 2>&1; then
    echo "Installation de Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "[OK] Helm deja installe"
fi
echo "[OK] Helm : $(helm version --short 2>/dev/null)"

# git (push vers GitLab) et jq (appels a l'API GitLab dans configure_gitlab.sh)
MISSING=""
command -v git >/dev/null 2>&1 || MISSING="$MISSING git"
command -v jq  >/dev/null 2>&1 || MISSING="$MISSING jq"
if [ -n "$MISSING" ]; then
    echo "Installation de :$MISSING"
    sudo apt-get update -y
    # shellcheck disable=SC2086
    sudo apt-get install -y $MISSING
fi
echo "[OK] git : $(git --version)"
echo "[OK] jq  : $(jq --version)"

echo "Installation terminee. Prochaine etape : ./scripts/setup_cluster.sh"
