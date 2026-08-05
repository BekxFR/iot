#!/bin/bash
# Verification de la partie 3 : cluster, namespaces, Argo CD, application.

NAMESPACE_ARGOCD="argocd"
NAMESPACE_DEV="dev"

echo "=== Tests - P3 ==="

echo "Cluster info:"
kubectl cluster-info
kubectl get nodes

echo "Namespaces:"
kubectl get namespaces | grep -E "(argocd|dev)"

echo "Argo CD pods:"
kubectl get pods -n $NAMESPACE_ARGOCD

echo "Application Argo CD:"
kubectl get application -n $NAMESPACE_ARGOCD -o wide 2>/dev/null || echo "  Aucune Application declaree"

echo "Ressources du namespace dev:"
kubectl get pods -n $NAMESPACE_DEV
kubectl get svc -n $NAMESPACE_DEV
kubectl get ingress -n $NAMESPACE_DEV

echo "Image deployee:"
kubectl get deployment wil-playground -n $NAMESPACE_DEV \
    -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}' 2>/dev/null \
    || echo "  Deployment absent"

echo "Test de l'application via l'Ingress (http://localhost:8888)..."
response=$(curl -s --max-time 10 http://localhost:8888/ || true)

if echo "$response" | grep -q "status"; then
    echo "[OK] Application accessible"
    echo "  Reponse: $response"
    if echo "$response" | grep -q "v2"; then
        echo "  Version v2 detectee"
    elif echo "$response" | grep -q "v1"; then
        echo "  Version v1 detectee"
    else
        echo "  Version non identifiee"
    fi
else
    echo "[FAIL] Application non accessible sur http://localhost:8888"
    echo "       Repli possible: kubectl port-forward svc/wil-playground-service -n $NAMESPACE_DEV 8888:8888"
fi

echo "Argo CD credentials:"
if kubectl get secret argocd-initial-admin-secret -n $NAMESPACE_ARGOCD >/dev/null 2>&1; then
    ARGOCD_PASSWORD=$(kubectl -n $NAMESPACE_ARGOCD get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    echo "  kubectl port-forward svc/argocd-server -n $NAMESPACE_ARGOCD 8080:443"
    echo "  URL      : https://localhost:8080"
    echo "  Username : admin"
    echo "  Password : $ARGOCD_PASSWORD"
else
    echo "  [FAIL] Secret Argo CD non trouve"
fi
