# Bonus - GitLab local sur K3d

## Description

Cette partie bonus ajoute un GitLab local au cluster K3d. Argo CD synchronise depuis le GitLab local (au lieu de GitHub). L'application `wil42/playground` reste dans le namespace `dev`, accessible sur le port 8888.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Cluster K3d (iot-bonus)                  │
│                                                             │
│  ┌─────────────────┐  sync   ┌────────────────────────────┐ │
│  │  Argo CD        │ ──────► │  GitLab                    │ │
│  │  (ns: argocd)   │         │  (ns: gitlab)              │ │
│  └────────┬────────┘         │  - webservice              │ │
│           │ deploy           │  - gitaly                  │ │
│           ▼                  │  - sidekiq                 │ │
│  ┌─────────────────┐         │  - postgresql              │ │
│  │  wil-playground │         │  - redis                   │ │
│  │  (ns: dev)      │         │  - minio                   │ │
│  │  port: 8888     │         └────────────────────────────┘ │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

## Namespaces

| Namespace | Contenu |
|-----------|---------|
| `argocd`  | Argo CD (serveur, repo-server, etc.) |
| `dev`     | Application wil-playground (deployment, service, ingress) |
| `gitlab`  | GitLab complet (webservice, gitaly, sidekiq, postgresql, redis, minio) |

## Outils utilises

| Outil | Role |
|-------|------|
| **Docker** | Moteur de conteneurs, necessaire pour faire tourner le cluster K3d sur la machine hote |
| **K3d** | Cree un cluster Kubernetes leger (K3s) a l'interieur de conteneurs Docker, evitant le besoin de VMs |
| **kubectl** | Client en ligne de commande pour interagir avec l'API Kubernetes (deployer, inspecter, debugger) |
| **Helm** | Gestionnaire de paquets Kubernetes - permet d'installer GitLab via son chart officiel `gitlab/gitlab` avec un seul fichier de valeurs au lieu de dizaines de manifestes YAML |
| **Argo CD CLI** | Client pour Argo CD, le moteur GitOps qui surveille un repo Git et synchronise automatiquement l'etat du cluster |
| **git** | Necessaire pour cloner le projet GitLab local, y pousser les manifestes, et effectuer la demo de changement de version (v1 -> v2) |

## Prerequis

- Docker (accessible sans sudo - `newgrp docker` si necessaire)
- ~3 CPU, 6 GB RAM minimum pour GitLab

## Installation

### Via le Makefile (recommande)

```bash
# Pipeline complet
make bonus

# Ou etape par etape
make bonus-install    # Installe Helm + outils P3 si absents
make bonus-setup      # Cree cluster K3d + Argo CD + 3 namespaces
make bonus-gitlab     # Deploie et configure GitLab (~15 min)
make bonus-deploy     # Deploie l'app via Argo CD -> GitLab local
```

### En direct

```bash
cd bonus
./scripts/install.sh
./scripts/setup_cluster.sh
./scripts/deploy_gitlab.sh
./scripts/configure_gitlab.sh
./scripts/deploy_app.sh
```

## Verification

```bash
make bonus-test
```

Verifie :
- Cluster K3d existe
- 3 namespaces : argocd, dev, gitlab
- Pods GitLab en Running
- Pods Argo CD en Running
- App dans dev en Running
- App repond sur port 8888
- Source Argo CD pointe vers GitLab (pas GitHub)

## Acces

### Application (port 8888)

Le port 8888 de l'hôte est publié sur l'entrypoint HTTP du loadbalancer K3d :
l'Ingress Traefik expose l'application directement.

```bash
curl http://localhost:8888

# Repli si besoin
kubectl port-forward svc/wil-playground-service -n dev 8888:8888
```

### Argo CD (port 8080)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# URL: https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### GitLab (port 30080)

```bash
kubectl port-forward svc/gitlab-webservice-default -n gitlab 30080:8181
# URL: http://localhost:30080
# Username: root
# Password: kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d
```

## Demonstration GitOps v1 -> v2

1. **Port-forward vers GitLab** :
   ```bash
   kubectl port-forward svc/gitlab-webservice-default -n gitlab 30080:8181 &
   ```

2. **Recuperer le mot de passe GitLab** :
   ```bash
   GITLAB_PWD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d)
   ```

3. **Cloner, modifier, push** :
   ```bash
   git clone http://root:$GITLAB_PWD@localhost:30080/root/iot-app.git /tmp/iot-app
   cd /tmp/iot-app
   sed -i 's/wil42\/playground:v1/wil42\/playground:v2/' deployment.yaml
   git add . && git commit -m "Upgrade to v2" && git push
   ```

4. **Verifier** (Argo CD synchronise en ~3 min) :
   ```bash
   curl http://localhost:8888
   # -> v2
   ```

## Flux GitOps

```
Utilisateur push vers GitLab local
  -> Argo CD detecte le changement (polling ~3 min)
    -> Argo CD synchronise les manifestes
      -> Kubernetes deploie la nouvelle version dans dev
```

## Differences avec la Partie 3

| Aspect | Partie 3 | Bonus |
|--------|----------|-------|
| Source Git | GitHub (externe) | GitLab (local, dans le cluster) |
| Namespaces | argocd, dev | argocd, dev, gitlab |
| Outils supplementaires | - | Helm |
| Ressources | Legeres | ~3 CPU, 6 GB RAM (GitLab) |
| Deploiement GitLab | - | Helm chart officiel gitlab/gitlab |

## Configuration GitLab

Le chart Helm est configure avec des parametres minimaux (`confs/gitlab-values.yaml`) :
- Pas de certmanager, nginx-ingress, prometheus, runner, registry, KAS, pages
- Replicas reduites a 1
- HTTP uniquement (pas de TLS)
- Communication Argo CD -> GitLab via DNS interne Kubernetes

## Nettoyage

```bash
make bonus-clean    # Supprime le cluster K3d + Docker prune
make fclean         # Nettoyage force de tout le projet
```

## Structure des fichiers

```
bonus/
├── README.md
├── scripts/
│   ├── install.sh              # Installe Helm (+ outils P3 si absents)
│   ├── setup_cluster.sh        # Cree cluster K3d + Argo CD + 3 namespaces
│   ├── deploy_gitlab.sh        # Deploie GitLab via Helm chart officiel
│   ├── configure_gitlab.sh     # Cree projet GitLab, push manifestes, enregistre repo dans Argo CD
│   ├── deploy_app.sh           # Applique application.yaml Argo CD -> GitLab local
│   ├── test.sh                 # Verifie tout (GitLab, Argo CD, app, GitOps)
│   └── cleanup.sh              # Supprime cluster + nettoyage
└── confs/
    ├── gitlab-values.yaml      # Helm values minimaux pour GitLab
    ├── application.yaml        # Argo CD Application -> GitLab local
    ├── deployment.yaml         # Manifeste Kubernetes (wil42/playground:v1)
    ├── service.yaml            # Service ClusterIP port 8888
    └── ingress.yaml            # Ingress Traefik
```
