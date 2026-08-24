#!/bin/bash
# Cluster K3d du bonus : namespaces argocd, dev et gitlab + installation d'Argo CD.
set -e

CLUSTER_NAME="iot-bonus"
NAMESPACE_ARGOCD="argocd"
NAMESPACE_DEV="dev"
NAMESPACE_GITLAB="gitlab"

# Version d'Argo CD EPINGLEE. "stable" suit la derniere version publiee et a
# deja casse ce script : entre la v3.0.0 et la v3.5.1, le CRD applicationsets
# est passe de 258 839 a 343 248 octets.
#
# --server-side est obligatoire au-dela de 262 144 octets : un `kubectl apply`
# classique recopie le manifeste dans l'annotation
# kubectl.kubernetes.io/last-applied-configuration, plafonnee a cette taille,
# et l'API server refuse avec "metadata.annotations: Too long".
# En server-side apply, c'est l'API server qui suit les champs via
# metadata.managedFields : plus d'annotation, plus de plafond.
#
# Pas de --force-conflicts : le cluster est detruit puis recree juste au-dessus,
# aucun gestionnaire de champs anterieur n'existe donc. Ce drapeau ne ferait que
# masquer un futur conflit reel.
ARGOCD_VERSION="v3.5.1"

echo "=== Configuration du cluster K3d - Bonus GitLab ==="

if ! docker ps >/dev/null 2>&1; then
    echo "[FAIL] Docker n'est pas accessible. Executez 'newgrp docker' ou redemarrez votre session."
    exit 1
fi

echo "Nettoyage des clusters existants..."
k3d cluster delete $CLUSTER_NAME 2>/dev/null || true

# Le port 8888 de l'hote est branche sur l'entrypoint HTTP (port 80) du
# loadbalancer : l'Ingress Traefik expose l'application sur http://localhost:8888.
echo "Creation du cluster K3d '$CLUSTER_NAME'..."
k3d cluster create $CLUSTER_NAME \
    --port "8888:80@loadbalancer" \
    --port "8443:443@loadbalancer" \
    --api-port 6550 \
    --servers 1 \
    --agents 2 \
    --wait

echo "Verification du cluster..."
kubectl cluster-info
kubectl get nodes

echo "Creation des namespaces..."
kubectl create namespace $NAMESPACE_ARGOCD --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $NAMESPACE_DEV --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace $NAMESPACE_GITLAB --dry-run=client -o yaml | kubectl apply -f -

echo "Installation d'Argo CD..."
kubectl apply --server-side -n $NAMESPACE_ARGOCD \
    -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"

echo "Attente du demarrage d'Argo CD..."
kubectl rollout status deployment/argocd-repo-server -n $NAMESPACE_ARGOCD --timeout=600s
kubectl rollout status deployment/argocd-server -n $NAMESPACE_ARGOCD --timeout=600s
if kubectl get statefulset argocd-application-controller -n $NAMESPACE_ARGOCD >/dev/null 2>&1; then
    kubectl rollout status statefulset/argocd-application-controller -n $NAMESPACE_ARGOCD --timeout=600s
fi

echo "Recuperation du mot de passe admin Argo CD..."
ARGOCD_PASSWORD=$(kubectl -n $NAMESPACE_ARGOCD get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "[OK] Cluster K3d configure."
echo ""
echo "Interface Argo CD (service en ClusterIP, acces par port-forward) :"
echo "  kubectl port-forward svc/argocd-server -n $NAMESPACE_ARGOCD 8080:443"
echo "  URL      : https://localhost:8080"
echo "  Login    : admin"
echo "  Password : $ARGOCD_PASSWORD"
echo ""
echo "Prochaine etape : ./scripts/deploy_gitlab.sh"
