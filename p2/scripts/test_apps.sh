#!/bin/bash

echo "=== Test des Applications - P2 ==="

test_url() {
    local host=$1
    local expected=$2

    if [[ "$host" == "default" ]]; then
        result=$(curl -s http://192.168.56.110)
    else
        result=$(curl -s -H "Host: $host" http://192.168.56.110)
    fi

    if [[ $result == *"$expected"* ]]; then
        echo "[PASS] $host"
    else
        echo "[FAIL] $host - got: $result"
    fi
}

echo "Attente des services..."
sleep 10

test_url "app1.com" "Application 1"
test_url "app2.com" "Application 2"
test_url "default" "Application 3"

echo "Statut du cluster:"
kubectl get nodes -o wide
kubectl get all
kubectl get ingress
