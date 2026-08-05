#!/bin/bash
# Installation des outils necessaires a la partie 3 (Debian ou Ubuntu).
# Idempotent : chaque outil deja present est laisse en place.
set -e

echo "=== Installation P3 - K3d et Argo CD ==="

if [ ! -r /etc/os-release ]; then
    echo "[FAIL] /etc/os-release introuvable : distribution non supportee"
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

# Depot Docker : ubuntu ou debian (les derives retombent sur leur base ID_LIKE).
case "$ID" in
    ubuntu|debian) DOCKER_DISTRO="$ID" ;;
    *)             DOCKER_DISTRO=$(echo "${ID_LIKE:-debian}" | awk '{print $1}') ;;
esac
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null)}}"

echo "Distribution detectee : $PRETTY_NAME (depot docker: $DOCKER_DISTRO/$CODENAME)"

echo "Installation des dependances de base..."
sudo apt-get update -y
sudo apt-get install -y \
    curl \
    wget \
    git \
    jq \
    ca-certificates \
    gnupg \
    lsb-release

# ============================================================
# Docker
# ============================================================
if command -v docker >/dev/null 2>&1; then
    echo "[OK] Docker deja installe : $(docker --version)"
else
    echo "Installation de Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$DOCKER_DISTRO/gpg" \
        | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$DOCKER_DISTRO $CODENAME stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    sudo systemctl enable --now docker
fi

# Docker sans sudo (exigence de la partie 3)
if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    sudo usermod -aG docker "$USER"
    echo "[INFO] $USER ajoute au groupe docker : reconnectez-vous ou lancez 'newgrp docker'"
fi

# ============================================================
# kubectl
# ============================================================
if command -v kubectl >/dev/null 2>&1; then
    echo "[OK] kubectl deja installe"
else
    echo "Installation de kubectl..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    TMP=$(mktemp -d)
    curl -sSL -o "$TMP/kubectl" "https://dl.k8s.io/release/$KUBECTL_VERSION/bin/linux/amd64/kubectl"
    sudo install -m 0755 "$TMP/kubectl" /usr/local/bin/kubectl
    rm -rf "$TMP"
fi

# ============================================================
# k3d
# ============================================================
if command -v k3d >/dev/null 2>&1; then
    echo "[OK] k3d deja installe : $(k3d --version | head -1)"
else
    echo "Installation de k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# ============================================================
# Argo CD CLI
# ============================================================
if command -v argocd >/dev/null 2>&1; then
    echo "[OK] Argo CD CLI deja installe"
else
    echo "Installation d'Argo CD CLI..."
    TMP=$(mktemp -d)
    curl -sSL -o "$TMP/argocd" https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 0755 "$TMP/argocd" /usr/local/bin/argocd
    rm -rf "$TMP"
fi

# ============================================================
# Verifications
# ============================================================
echo ""
echo "Verification des installations..."
docker --version           || echo "[FAIL] Docker non installe"
kubectl version --client   || echo "[FAIL] kubectl non installe"
k3d --version              || echo "[FAIL] k3d non installe"
argocd version --client    || echo "[FAIL] Argo CD CLI non installe"

echo ""
echo "Si Docker exige encore sudo : reconnectez-vous ou lancez 'newgrp docker'"
echo "Prochaine etape: ./scripts/setup_cluster.sh"
