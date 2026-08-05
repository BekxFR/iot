#!/bin/bash

echo "=== Nettoyage P3 ==="

CLUSTER_NAME="iot-cluster"

echo "Suppression du cluster K3d '$CLUSTER_NAME'..."
k3d cluster delete $CLUSTER_NAME

echo "Nettoyage des ressources Docker..."
docker system prune -f

echo "Clusters restants:"
k3d cluster list

echo "[OK] Nettoyage termine."
