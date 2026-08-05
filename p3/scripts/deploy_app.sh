#!/bin/bash
# Declaration de l'Application Argo CD : c'est Argo CD qui deploie ensuite
# les manifests depuis le depot GitHub public vers le namespace dev.
set -e

NAMESPACE_ARGOCD="argocd"
NAMESPACE_DEV="dev"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
P3_DIR="$(dirname "$SCRIPT_DIR")"
APPLICATION="$P3_DIR/confs/application.yaml"

GITHUB_REPO=$(awk '/repoURL:/ {print $2; exit}' "$APPLICATION")

echo "=== Deploiement via Argo CD - P3 ==="

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "[FAIL] Cluster K3d non accessible. Lancez d'abord: ./scripts/setup_cluster.sh"
    exit 1
fi

if ! kubectl get deployment argocd-server -n $NAMESPACE_ARGOCD >/dev/null 2>&1; then
    echo "[FAIL] Argo CD n'est pas installe. Lancez d'abord: ./scripts/setup_cluster.sh"
    exit 1
fi

kubectl get namespace $NAMESPACE_ARGOCD $NAMESPACE_DEV

echo "Declaration de l'Application Argo CD (repo: $GITHUB_REPO)..."
kubectl apply -f "$APPLICATION"

# Argo CD doit d'abord creer les ressources : on attend l'apparition du pod
# avant d'attendre sa disponibilite.
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
    echo "[WARN] Pas de reponse via l'Ingress, essai en port-forward :"
    echo "       kubectl port-forward svc/wil-playground-service -n $NAMESPACE_DEV 8888:8888"
fi

echo "[OK] Deploiement termine."
