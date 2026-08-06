#!/bin/bash
# Deploiement des 3 applications web et de l'Ingress de routage par HOST.
set -e

CONFS="/vagrant/confs"
NODE_IP="${NODE_IP:-192.168.56.110}"

echo "=== Deploiement des applications - P2 ==="

echo "Attente de K3s..."
for i in $(seq 1 60); do
    if kubectl get nodes >/dev/null 2>&1; then
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[FAIL] K3s indisponible"
        exit 1
    fi
    sleep 5
done

# Les objets sont crees dans le namespace 'default' : c'est ce que montre la
# sortie de reference du sujet, et 'kubectl get all' suffit alors a voir les
# trois applications sans avoir a preciser de namespace.

echo "Deploiement de app1 (1 replica)..."
kubectl apply -f "$CONFS/app1-deployment.yaml"

echo "Deploiement de app2 (3 replicas)..."
kubectl apply -f "$CONFS/app2-deployment.yaml"

echo "Deploiement de app3 (defaut)..."
kubectl apply -f "$CONFS/app3-deployment.yaml"

echo "Configuration des services..."
kubectl apply -f "$CONFS/app1-service.yaml"
kubectl apply -f "$CONFS/app2-service.yaml"
kubectl apply -f "$CONFS/app3-service.yaml"

echo "Configuration de l'Ingress..."
kubectl apply -f "$CONFS/ingress.yaml"

echo "Attente du demarrage des applications..."
kubectl rollout status deployment/app1 --timeout=300s
kubectl rollout status deployment/app2 --timeout=300s
kubectl rollout status deployment/app3 --timeout=300s

kubectl get all
kubectl get ingress

echo "[OK] Applications deployees."
echo "  curl -H 'Host: app1.com' http://$NODE_IP  -> app1"
echo "  curl -H 'Host: app2.com' http://$NODE_IP  -> app2 (3 replicas)"
echo "  curl http://$NODE_IP                      -> app3 (defaut)"
