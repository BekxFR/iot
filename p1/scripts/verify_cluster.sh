#!/bin/bash
# Verification du cluster K3s de la partie 1 (a lancer depuis chillionS).

NODE_IP="${NODE_IP:-192.168.56.110}"

echo "=== Verification - P1 ==="

export KUBECONFIG="/home/vagrant/.kube/config"

echo "Nodes:"
kubectl get nodes -o wide

echo "Pods systeme:"
kubectl get pods -n kube-system

echo "Reseau:"
IFACE=$(ip -o -4 addr show | awk -v ip="$NODE_IP" '$4 ~ "^"ip"/" {print $2; exit}')
echo "  IP serveur: $NODE_IP"
echo "  Interface : ${IFACE:-non detectee}"

echo "Cluster info:"
kubectl cluster-info

echo "Test deploiement pod..."
kubectl run test-verification --image=nginx:alpine --restart=Never >/dev/null 2>&1
if kubectl wait --for=condition=ready pod/test-verification --timeout=120s >/dev/null 2>&1; then
    echo "[PASS] Deploiement de pod"
    kubectl get pod test-verification
else
    echo "[FAIL] Deploiement de pod"
    kubectl describe pod test-verification 2>/dev/null | tail -20
fi
kubectl delete pod test-verification --ignore-not-found --timeout=60s >/dev/null 2>&1

echo "Services systeme:"
kubectl get svc -n kube-system

echo "Version K3s:"
kubectl version

node_count=$(kubectl get nodes --no-headers | wc -l)
if [ "$node_count" -eq 2 ]; then
    echo "[PASS] Nodes: $node_count (server + worker)"
else
    echo "[FAIL] Nodes: $node_count (attendu: 2)"
fi

ready_count=$(kubectl get nodes --no-headers | grep -c ' Ready ')
if [ "$ready_count" -eq 2 ]; then
    echo "[PASS] Nodes Ready: $ready_count/2"
else
    echo "[FAIL] Nodes Ready: $ready_count/2"
fi
