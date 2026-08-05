#!/bin/bash

echo "=== Nettoyage du Bonus GitLab ==="

CLUSTER_NAME="iot-bonus"

echo "Suppression du cluster K3d '$CLUSTER_NAME'..."
k3d cluster delete $CLUSTER_NAME 2>/dev/null || true

echo "Nettoyage des ressources Docker..."
docker system prune -f 2>/dev/null || true

echo "Verification des clusters restants..."
k3d cluster list 2>/dev/null || true

echo "Nettoyage termine. Pour recreer le bonus: make bonus"
