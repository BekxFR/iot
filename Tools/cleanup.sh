#!/bin/bash

echo "=== Nettoyage des fichiers générés - Projet IoT ==="

# Fonction pour supprimer avec confirmation
safe_remove() {
    local path="$1"
    local description="$2"
    
    if [ -e "$path" ]; then
        echo "Suppression: $description"
        rm -rf "$path"
        echo "   $path supprimé"
    fi
}

# Fonction pour supprimer sans confirmation (fichiers temporaires)
force_remove() {
    local pattern="$1"
    local description="$2"
    
    if find . -name "$pattern" -type f 2>/dev/null | grep -q .; then
        echo "Nettoyage: $description"
        find . -name "$pattern" -type f -delete
        echo "   Fichiers $pattern supprimés"
    fi
}

echo ""
echo "Recherche des fichiers à nettoyer..."

# Nettoyage Vagrant
echo ""
echo "Nettoyage Vagrant..."
safe_remove "p1/.vagrant" "Dossier Vagrant p1"
safe_remove "p2/.vagrant" "Dossier Vagrant p2"
force_remove "*.log" "Fichiers de logs"

# Nettoyage Docker/K3d
echo ""
echo "Nettoyage Docker/K3d..."
if command -v k3d >/dev/null 2>&1; then
    echo "Vérification des clusters K3d..."
    if k3d cluster list 2>/dev/null | grep -q "iot-cluster"; then
        echo " !  Cluster K3d 'iot-cluster' détecté"
        read -p "Voulez-vous le supprimer ? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            k3d cluster delete iot-cluster
            echo "   Cluster supprimé"
        fi
    fi
fi

# Nettoyage Kubernetes
echo ""
echo "Nettoyage Kubernetes..."
safe_remove ".kube/config.bak" "Backup kubeconfig"
force_remove "*.kubeconfig" "Fichiers kubeconfig temporaires"

# Nettoyage des fichiers temporaires
echo ""
echo "Nettoyage fichiers temporaires..."
force_remove "*.tmp" "Fichiers temporaires"
force_remove "*.bak" "Fichiers de backup"
force_remove "*~" "Fichiers de sauvegarde éditeur"

# Nettoyage des logs
echo ""
echo "Nettoyage logs..."
safe_remove "logs" "Dossier logs"
safe_remove ".logs" "Dossier logs caché"

# Nettoyage cache
echo ""
echo "Nettoyage cache..."
safe_remove "cache" "Dossier cache"
safe_remove ".cache" "Dossier cache caché"

# Nettoyage des données persistantes de test
echo ""
echo "Nettoyage données de test..."
safe_remove "data" "Dossier data"
safe_remove "test-repo" "Repository de test"

# Nettoyage spécifique aux éditeurs
echo ""
echo "Nettoyage éditeurs..."
safe_remove ".vscode" "Configuration VS Code"
safe_remove ".idea" "Configuration IntelliJ"
force_remove ".DS_Store" "Fichiers macOS"

echo ""
echo "Vérification du statut Git..."
if [ -d ".git" ]; then
    echo "Fichiers suivis par Git:"
    git status --porcelain | head -10
    echo ""
    echo "Fichiers ignorés (échantillon):"
    git status --ignored --porcelain | head -5
else
    echo "Pas de repository Git détecté"
fi

echo ""
echo "Nettoyage terminé !"
echo ""
echo "Conseils:"
echo "   - Utilisez 'git status --ignored' pour voir les fichiers ignorés"
echo "   - Le fichier .gitignore protège contre les commits accidentels"
echo "   - Relancez ce script après chaque test des parties"
