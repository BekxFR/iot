#!/bin/bash

echo "=== Deploiement de GitLab via Helm - Bonus ==="

NAMESPACE_GITLAB="gitlab"

# Verification du cluster
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "[FAIL] Cluster K3d non accessible. Lancez d'abord : ./scripts/setup_cluster.sh"
    exit 1
fi

# Ajout du repo Helm GitLab
echo "Ajout du repo Helm GitLab..."
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# Installation de GitLab
echo "Installation de GitLab dans le namespace '$NAMESPACE_GITLAB' (10-15 min)..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(dirname "$SCRIPT_DIR")"

helm upgrade --install gitlab gitlab/gitlab \
    --namespace $NAMESPACE_GITLAB \
    --create-namespace \
    -f "$BONUS_DIR/confs/gitlab-values.yaml" \
    --timeout 900s

# Attente des migrations de base de donnees
echo "Attente des migrations GitLab..."
kubectl wait --for=condition=complete job -l app=migrations -n $NAMESPACE_GITLAB --timeout=600s 2>/dev/null || true

# Attente du service web GitLab
echo "Attente du service web GitLab..."
for i in $(seq 1 60); do
    READY=$(kubectl get pods -n $NAMESPACE_GITLAB -l app=webservice -o jsonpath='{.items[0].status.containerStatuses[*].ready}' 2>/dev/null | tr ' ' '\n' | grep -c "true")
    TOTAL=$(kubectl get pods -n $NAMESPACE_GITLAB -l app=webservice -o jsonpath='{.items[0].status.containerStatuses[*].ready}' 2>/dev/null | wc -w)
    if [ "$READY" = "$TOTAL" ] && [ "$TOTAL" -gt 0 ] 2>/dev/null; then
        echo "[OK] Service web GitLab pret"
        break
    fi
    echo "  ... Attente du webservice ($i/60)"
    sleep 15
done

# Attente de Gitaly
echo "Attente de Gitaly..."
kubectl wait --for=condition=ready pod -l app=gitaly -n $NAMESPACE_GITLAB --timeout=300s 2>/dev/null || true

echo "Etat des pods GitLab:"
kubectl get pods -n $NAMESPACE_GITLAB

echo "GitLab deploye. Prochaine etape : ./scripts/configure_gitlab.sh"
