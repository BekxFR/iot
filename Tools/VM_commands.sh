#!/bin/bash
# Preparation de la VM d'evaluation du projet IoT (Debian ou Ubuntu).
# Installe tous les prerequis des parties p1, p2, p3 et bonus.
# Le script est idempotent : un outil deja present n'est pas reinstalle.
#
# Usage:
#   ./VM_commands.sh              # Installation de base (obligatoire)
#   ./VM_commands.sh --with-ide   # + VSCode et Claude Code (optionnel)

set -e

INSTALL_IDE=false
if [ "$1" = "--with-ide" ]; then
    INSTALL_IDE=true
fi

if [ ! -r /etc/os-release ]; then
    echo "[FAIL] /etc/os-release introuvable : distribution non supportee"
    exit 1
fi
# shellcheck disable=SC1091
. /etc/os-release

case "$ID" in
    debian|ubuntu) ;;
    *)
        if ! echo "${ID_LIKE:-}" | grep -qE 'debian|ubuntu'; then
            echo "[FAIL] Distribution non supportee : $PRETTY_NAME (Debian ou Ubuntu attendu)"
            exit 1
        fi
        ;;
esac

# Depot Docker : ubuntu ou debian (les derives retombent sur leur base ID_LIKE).
case "$ID" in
    ubuntu|debian) BASE_ID="$ID" ;;
    *)             BASE_ID=$(echo "${ID_LIKE:-debian}" | awk '{print $1}') ;;
esac
CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-$(lsb_release -cs 2>/dev/null)}}"

echo "=== Installation des prerequis IoT ==="
echo "Distribution : $PRETTY_NAME (base: $BASE_ID, codename: $CODENAME)"

# ============================================================
# Verification prealable : virtualisation imbriquee
# Les parties 1 et 2 lancent des VM VirtualBox DANS cette machine.
# ============================================================
if ! grep -qE '(vmx|svm)' /proc/cpuinfo; then
    echo ""
    echo "[WARN] VT-x / AMD-V n'est pas expose a cette machine."
    echo "       VirtualBox ne pourra pas demarrer les VM des parties 1 et 2."
    echo "       Activez la virtualisation imbriquee dans l'hyperviseur hote"
    echo "       (VirtualBox: VBoxManage modifyvm <vm> --nested-hw-virt on)."
    echo ""
else
    echo "[OK] Virtualisation materielle disponible"
fi

# ============================================================
# Dependances de base
# Pas de 'apt-get upgrade' ici : une mise a jour du noyau juste avant la
# compilation du module vboxdrv casse VirtualBox jusqu'au redemarrage.
# ============================================================
echo "Installation des dependances de base..."
sudo apt-get update -y
sudo apt-get install -y \
    curl wget git make jq \
    build-essential dkms \
    net-tools gnupg lsb-release \
    software-properties-common apt-transport-https ca-certificates

# En-tetes du noyau courant (necessaires a la compilation de vboxdrv)
sudo apt-get install -y "linux-headers-$(uname -r)" 2>/dev/null \
    || sudo apt-get install -y linux-headers-generic 2>/dev/null \
    || sudo apt-get install -y linux-headers-amd64 2>/dev/null \
    || echo "[WARN] En-tetes du noyau non installes : le module vboxdrv peut echouer"

# ============================================================
# VirtualBox (requis pour p1, p2)
# Debian : paquet dans la composante 'contrib'
# Ubuntu : paquet dans la composante 'multiverse'
# ============================================================
if command -v VBoxManage >/dev/null 2>&1; then
    echo "[OK] VirtualBox deja installe : $(VBoxManage --version)"
else
    echo "Installation de VirtualBox..."
    case "$BASE_ID" in
        ubuntu) sudo add-apt-repository -y multiverse >/dev/null 2>&1 || true ;;
        debian) sudo add-apt-repository -y contrib    >/dev/null 2>&1 || true ;;
    esac
    sudo apt-get update -y

    if ! sudo apt-get install -y virtualbox; then
        echo "[WARN] Paquet 'virtualbox' indisponible, bascule sur le depot officiel Oracle..."
        curl -fsSL https://www.virtualbox.org/download/oracle_vbox_2016.asc \
            | sudo gpg --dearmor --yes -o /usr/share/keyrings/oracle-vbox.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/oracle-vbox.gpg] https://download.virtualbox.org/virtualbox/debian $CODENAME contrib" \
            | sudo tee /etc/apt/sources.list.d/virtualbox.list > /dev/null
        sudo apt-get update -y
        sudo apt-get install -y virtualbox-7.1 \
            || sudo apt-get install -y virtualbox-7.0 \
            || {
                echo "[FAIL] Installation de VirtualBox impossible."
                echo "       Installez-le manuellement : https://www.virtualbox.org/wiki/Linux_Downloads"
                exit 1
            }
    fi
fi

# Acces aux peripheriques VirtualBox pour l'utilisateur courant
if getent group vboxusers >/dev/null 2>&1; then
    if ! id -nG "$USER" | tr ' ' '\n' | grep -qx vboxusers; then
        sudo usermod -aG vboxusers "$USER"
        echo "[INFO] $USER ajoute au groupe vboxusers (reconnexion necessaire)"
    fi
fi

# Secure Boot : le module vboxdrv doit etre signe et la cle enrolee (MOK)
if [ -d /sys/firmware/efi ] && command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state 2>/dev/null | grep -qi enabled; then
        echo "[WARN] Secure Boot actif : le module vboxdrv doit etre signe et sa cle"
        echo "       enrolee (mokutil --import). Sinon, desactivez Secure Boot."
    fi
fi

# ============================================================
# Vagrant (requis pour p1, p2)
# ============================================================
if command -v vagrant >/dev/null 2>&1; then
    echo "[OK] Vagrant deja installe : $(vagrant --version)"
else
    echo "Installation de Vagrant..."
    wget -qO- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | \
        sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $CODENAME main" | \
        sudo tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
    sudo apt-get update -y
    sudo apt-get install -y vagrant
fi

# ============================================================
# Docker (requis pour p3, bonus)
# ============================================================
if command -v docker >/dev/null 2>&1; then
    echo "[OK] Docker deja installe : $(docker --version)"
else
    echo "Installation de Docker..."
    sudo apt-get install -y docker.io
    sudo systemctl enable --now docker
fi

if ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    sudo usermod -aG docker "$USER"
    echo "[INFO] $USER ajoute au groupe docker (reconnexion ou 'newgrp docker')"
fi

# ============================================================
# kubectl (requis pour p1, p2, p3, bonus)
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
# K3d (requis pour p3, bonus)
# ============================================================
if command -v k3d >/dev/null 2>&1; then
    echo "[OK] k3d deja installe : $(k3d --version | head -1)"
else
    echo "Installation de k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# ============================================================
# Argo CD CLI (requis pour p3, bonus)
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
# Helm (requis pour le bonus : deploiement GitLab)
# ============================================================
if command -v helm >/dev/null 2>&1; then
    echo "[OK] Helm deja installe : $(helm version --short 2>/dev/null)"
else
    echo "Installation de Helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# ============================================================
# Optionnel : VSCode + Claude Code
# ============================================================
if [ "$INSTALL_IDE" = true ]; then
    echo "=== Installation VSCode + Claude Code ==="

    if ! command -v code >/dev/null 2>&1; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | \
            sudo tee /usr/share/keyrings/packages.microsoft.gpg >/dev/null
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
            sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
        sudo apt-get update -y && sudo apt-get install -y code
    fi

    if ! command -v node >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if ! command -v claude >/dev/null 2>&1; then
        sudo npm install -g @anthropic-ai/claude-code
    fi

    echo "VSCode et Claude Code installes."
    echo "  Lancer VSCode      : code"
    echo "  Lancer Claude Code : claude"
fi

# ============================================================
# Verifications finales
# ============================================================
echo ""
echo "=== Verifications ==="
VBoxManage --version      >/dev/null 2>&1 && echo "[OK] VirtualBox   $(VBoxManage --version)" || echo "[FAIL] VirtualBox"
vagrant --version         >/dev/null 2>&1 && echo "[OK] Vagrant      $(vagrant --version)"    || echo "[FAIL] Vagrant"
docker --version          >/dev/null 2>&1 && echo "[OK] Docker       $(docker --version)"     || echo "[FAIL] Docker"
kubectl version --client  >/dev/null 2>&1 && echo "[OK] kubectl"                              || echo "[FAIL] kubectl"
k3d --version             >/dev/null 2>&1 && echo "[OK] k3d          $(k3d --version | head -1)" || echo "[FAIL] k3d"
argocd version --client   >/dev/null 2>&1 && echo "[OK] Argo CD CLI"                          || echo "[FAIL] Argo CD CLI"
helm version --short      >/dev/null 2>&1 && echo "[OK] Helm         $(helm version --short)" || echo "[FAIL] Helm"
jq --version              >/dev/null 2>&1 && echo "[OK] jq           $(jq --version)"         || echo "[FAIL] jq"

if [ "$INSTALL_IDE" = true ]; then
    code --version   >/dev/null 2>&1 && echo "[OK] VSCode"      || echo "[FAIL] VSCode"
    claude --version >/dev/null 2>&1 && echo "[OK] Claude Code" || echo "[FAIL] Claude Code"
fi

echo ""
echo "Installation terminee."
echo "NOTE: reconnectez-vous (groupes docker et vboxusers) ou lancez 'newgrp docker'."
echo "NOTE: si /tmp est un tmpfs ou trop petit, lancez les parties Vagrant avec"
echo "      make VM_STORAGE=\$HOME/iot-vms p1"
