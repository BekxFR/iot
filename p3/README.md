# Partie 3 - K3d et Argo CD

## Description

Cette partie implémente un cluster Kubernetes K3d avec Argo CD pour la gestion GitOps d'une application. L'objectif est de déployer automatiquement une application depuis un repository GitHub et de pouvoir changer de version via Git.

## Architecture

### Composants

- **K3d**: Cluster Kubernetes léger dans Docker
- **Argo CD**: Outil GitOps pour le déploiement continu
- **Application**: wil42/playground (versions v1 et v2)
- **GitHub**: Repository public pour les manifests Kubernetes

### Namespaces

- **argocd**: Dédié à Argo CD
- **dev**: Contient l'application déployée

## Conformité aux consignes

### Exigences respectées

1. **K3d installé** : Remplace Vagrant par Docker
2. **Script d'installation** : Installe tous les outils nécessaires
3. **Deux namespaces** :
   - `argocd` pour Argo CD
   - `dev` pour l'application
4. **Repository GitHub public** : Contient les manifests Kubernetes
5. **Application avec 2 versions** : wil42/playground:v1 et v2
6. **GitOps fonctionnel** : Changement de version via Git
7. **Port 8888** : Application accessible sur ce port

## Structure des fichiers

```
p3/
├── README.md                     # Documentation complète
├── scripts/
│   ├── install.sh               # Installation des outils
│   ├── setup_cluster.sh         # Création cluster K3d + Argo CD
│   ├── deploy_app.sh            # Déploiement application
│   ├── test.sh                  # Tests et vérifications
│   └── cleanup.sh               # Nettoyage
└── confs/
    ├── deployment.yaml          # Manifest application
    ├── service.yaml             # Service Kubernetes
    ├── ingress.yaml             # Ingress configuration
    ├── application.yaml         # Application Argo CD
    └── GITHUB_SETUP.md          # Instructions GitHub
```

## Installation et déploiement

### Prérequis

- Debian 12+ ou Ubuntu 22.04+ (le script d'installation gère les deux)
- Accès internet
- Droits administrateur (sudo)

### 1. Installation des outils

```bash
cd p3
chmod +x scripts/*.sh
./scripts/install.sh
```

**Important**: Redémarrez votre session ou exécutez `newgrp docker` après l'installation.

### 2. Configuration du cluster

```bash
./scripts/setup_cluster.sh
```

Cette commande :

- Crée le cluster K3d `iot-cluster`
- Installe Argo CD
- Configure les namespaces
- Expose les ports nécessaires

### 3. Déploiement de l'application

```bash
./scripts/deploy_app.sh
```

Ce script applique `confs/application.yaml` qui crée une ressource Argo CD Application.
Argo CD synchronise ensuite automatiquement les manifestes depuis le repo GitHub vers le namespace `dev`.

### 4. Tests et vérification

```bash
./scripts/test.sh
```

## Configuration GitOps

Le repo GitHub `BekxFR/trobert-iot-argocd-app` contient les manifestes Kubernetes (deployment.yaml, service.yaml, ingress.yaml).

`confs/application.yaml` référence ce repo et est appliqué par `deploy_app.sh` :

```yaml
spec:
  source:
    repoURL: https://github.com/BekxFR/trobert-iot-argocd-app.git
    path: .
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Argo CD surveille le repo et synchronise automatiquement tout changement vers le namespace `dev`.

## Accès aux services

### Application (wil42/playground)

Le cluster K3d publie le port 8888 de l'hôte sur l'entrypoint HTTP du
loadbalancer : l'Ingress Traefik expose donc l'application directement.

```bash
curl http://localhost:8888
# Réponse: {"status":"ok", "message": "v1"} ou "v2"

# Repli si besoin
kubectl port-forward svc/wil-playground-service -n dev 8888:8888
```

### Argo CD Interface

```bash
# Le service argocd-server reste en ClusterIP : accès par port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Accès: https://localhost:8080
# Username: admin
# Password: (voir output de setup_cluster.sh)
```

## Test du GitOps

### Changement de version v1 -> v2

```bash
# Dans votre repository GitHub
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' deployment.yaml
git add deployment.yaml
git commit -m "Update to v2"
git push origin main

# Vérification (après synchronisation Argo CD)
curl http://localhost:8888
# Réponse: {"status":"ok", "message": "v2"}
```

### Retour à v1

```bash
sed -i 's/wil42\/playground:v2/wil42\/playground:v1/g' deployment.yaml
git add deployment.yaml
git commit -m "Rollback to v1"
git push origin main
```

## Commandes utiles

### Gestion du cluster

```bash
# État du cluster
k3d cluster list
kubectl get nodes

# Logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl logs -n dev -l app=wil-playground
```

### Surveillance

```bash
# Pods
kubectl get pods -n argocd
kubectl get pods -n dev

# Services
kubectl get svc -n argocd
kubectl get svc -n dev

# Applications Argo CD
kubectl get applications -n argocd
```

### Debug

```bash
# Describe pod
kubectl describe pod -n dev -l app=wil-playground

# Exec dans un pod
kubectl exec -it -n dev deployment/wil-playground -- sh

# Port-forward services
kubectl port-forward svc/argocd-server -n argocd 8080:443
kubectl port-forward svc/wil-playground-service -n dev 8888:8888
```

## Nettoyage

### Suppression complète

```bash
./scripts/cleanup.sh
```

### Suppression sélective

```bash
# Supprimer l'application Argo CD
kubectl delete -f confs/application.yaml

# Supprimer le cluster
k3d cluster delete iot-cluster
```

## Troubleshooting

### Docker non accessible

```bash
# Vérifier Docker
docker ps

# Si erreur de permission
sudo usermod -aG docker $USER
newgrp docker
# ou redémarrer la session
```

### Argo CD non accessible

```bash
# Vérifier les pods
kubectl get pods -n argocd

# Redémarrer si nécessaire
kubectl rollout restart deployment/argocd-server -n argocd
```

### Application non accessible

```bash
# Vérifier l'état
kubectl get pods -n dev
kubectl describe pod -n dev -l app=wil-playground

# Vérifier les logs
kubectl logs -n dev -l app=wil-playground
```

### Port-forward ne fonctionne pas

```bash
# Vérifier que le service existe
kubectl get svc -n dev

# Utiliser un autre port local
kubectl port-forward svc/wil-playground-service -n dev 9999:8888
curl http://localhost:9999
```

## Différences K3s vs K3d

| Aspect       | K3s                  | K3d                |
| ------------ | -------------------- | ------------------ |
| Installation | Sur VM/serveur       | Dans Docker        |
| Ressources   | Plus lourdes         | Plus légères       |
| Persistance  | Données persistantes | Éphémère           |
| Usage        | Production           | Développement/Test |
| Networking   | Host network         | Docker network     |

## Avantages de cette architecture

1. **Isolation**: Cluster dans Docker, facile à supprimer
2. **Rapidité**: Démarrage en quelques secondes
3. **GitOps**: Déploiement automatique depuis Git
4. **Versioning**: Gestion facile des versions
5. **Observabilité**: Interface Argo CD pour monitoring

