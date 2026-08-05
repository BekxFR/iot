#!/bin/bash
# Script à exécuter sur votre machine hôte

echo "Configuration de l'accès K3s depuis la machine hôte..."

# Créer le répertoire kubectl
mkdir -p ~/.kube

# Récupérer la configuration
vagrant ssh chillionS -c "cat /home/vagrant/.kube/config" > ~/.kube/config-k3s

# Utiliser cette configuration
export KUBECONFIG=~/.kube/config-k3s

# Tester la connectivité
echo "Test de connectivité..."
kubectl get nodes -o wide

echo "Services accessibles :"
echo "- Traefik (proxy): http://192.168.56.110 ou http://192.168.56.111"
echo "- API K3s: https://192.168.56.110:6443"
echo "- Kubectl configuré avec: export KUBECONFIG=~/.kube/config-k3s"
echo "- Pour exposer une app: créer un Ingress"
echo "- Dashboard Traefik: kubectl port-forward -n kube-system svc/traefik 8080:8080"

# --------------------------------------

# Créer une app nginx simple
# kubectl create deployment nginx-test --image=nginx
# kubectl expose deployment nginx-test --port=80

# Créer un Ingress pour l'exposer via Traefik
# cat <<EOF | kubectl apply -f -
# apiVersion: networking.k8s.io/v1
# kind: Ingress
# metadata:
#   name: nginx-ingress
#   annotations:
#     traefik.ingress.kubernetes.io/router.entrypoints: web
# spec:
#   rules:
#   - host: nginx.local
#     http:
#       paths:
#       - path: /
#         pathType: Prefix
#         backend:
#           service:
#             name: nginx-test
#             port:
#               number: 80
# EOF

# Ajouter l'entrée DNS sur l'hôte
# echo "192.168.56.110 nginx.local" | sudo tee -a /etc/hosts

# Maintenant accessible sur :
# curl http://nginx.local

# --------------------------------------

# Voir les services Traefik
# kubectl get svc traefik -n kube-system

# Voir les pods Traefik
# kubectl get pods -n kube-system | grep traefik

# Voir l'état des pods du dashboard
# kubectl get pods -n kubernetes-dashboard

# Voir tous les services du dashboard
# kubectl get svc -n kubernetes-dashboard

# Voir les logs si problème
# kubectl logs -n kubernetes-dashboard deployment/kubernetes-dashboard

# Voir tous les objets créés
# kubectl get all -n kubernetes-dashboard

# Activer le dashboard Traefik
# kubectl patch deployment traefik -n kube-system -p '{"spec":{"template":{"spec":{"containers":[{"name":"traefik","args":["--api.dashboard=true","--api.insecure=true","--entrypoints.web.address=:80","--entrypoints.websecure.address=:443","--providers.kubernetescrd","--providers.kubernetesingress"]}]}}}}'

# Exposer le dashboard
# kubectl port-forward -n kube-system svc/traefik 8080:8080

# Installer le dashboard
# kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
# kubectl port-forward -n kubernetes-dashboard svc/kubernetes-dashboard 8443:443

