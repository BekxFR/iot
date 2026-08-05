#!/bin/bash

echo "Test de Traefik..."

# Configurer kubectl
export KUBECONFIG=~/.kube/config-k3s

# Créer une app de test
echo "Création d'une application test..."
kubectl create deployment hello-world --image=nginxdemos/hello --port=80
kubectl expose deployment hello-world --port=80

# Créer un Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-ingress
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: hello.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: hello-world
            port:
              number: 80
EOF

# Attendre que l'app soit prête
kubectl wait --for=condition=available deployment/hello-world --timeout=60s

echo ""
echo "Application déployée !"
echo "Ajouter à /etc/hosts : 192.168.56.110 hello.local"
echo "Accessible sur : http://hello.local"
echo ""
echo "Dashboard Traefik :"
echo "kubectl port-forward -n kube-system svc/traefik 8080:8080"
echo "Puis : http://localhost:8080"