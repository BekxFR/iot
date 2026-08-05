#!/bin/bash
# Declaration de l'Application Argo CD pointant sur le GitLab local.
set -e

NAMESPACE_ARGOCD="argocd"
NAMESPACE_DEV="dev"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(dirname "$SCRIPT_DIR")"
APPLICATION="$BONUS_DIR/confs/application.yaml"

echo "=== Deploiement de l'application via Argo CD - Bonus GitLab ==="

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "[FAIL] Cluster K3d non accessible. Lancez d'abord : ./scripts/setup_cluster.sh"
    exit 1
fi

if ! kubectl get deployment argocd-server -n $NAMESPACE_ARGOCD >/dev/null 2>&1; then
    echo "[FAIL] Argo CD n'est pas installe. Lancez d'abord : ./scripts/setup_cluster.sh"
    exit 1
fi

echo "Verification des namespaces..."
kubectl get namespace $NAMESPACE_ARGOCD $NAMESPACE_DEV

echo "Declaration de l'Application Argo CD (source: GitLab local)..."
kubectl apply -f "$APPLICATION"

# Argo CD doit d'abord cloner le depot GitLab et creer les ressources.
echo "Attente de la synchronisation Argo CD..."
for i in $(seq 1 60); do
    if kubectl get pods -n $NAMESPACE_DEV -l app=wil-playground --no-headers 2>/dev/null | grep -q .; then
        echo "[OK] Ressources synchronisees par Argo CD"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[FAIL] Aucun pod cree apres 5 minutes. Etat de l'Application :"
        kubectl get application -n $NAMESPACE_ARGOCD -o wide || true
        kubectl describe application wil-playground-app -n $NAMESPACE_ARGOCD | tail -30 || true
        exit 1
    fi
    echo "  ... attente de la synchronisation ($i/60)"
    sleep 5
done

kubectl wait --for=condition=ready pod -l app=wil-playground -n $NAMESPACE_DEV --timeout=300s

echo "Test de l'application via l'Ingress (http://localhost:8888)..."
RESPONSE=""
for i in $(seq 1 12); do
    RESPONSE=$(curl -s --max-time 5 http://localhost:8888/ || true)
    if echo "$RESPONSE" | grep -q "status"; then
        break
    fi
    sleep 5
done

if echo "$RESPONSE" | grep -q "status"; then
    echo "[OK] Application accessible sur http://localhost:8888"
    echo "     Reponse: $RESPONSE"
else
    echo "[WARN] Pas de reponse via l'Ingress, repli possible :"
    echo "       kubectl port-forward svc/wil-playground-service -n $NAMESPACE_DEV 8888:8888"
fi

echo "Deploiement termine. Commandes utiles:"
echo "  kubectl get pods -n $NAMESPACE_DEV"
echo "  kubectl logs -n $NAMESPACE_DEV -l app=wil-playground"
