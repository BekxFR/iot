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

## Outils utilisés

| Outil | Rôle |
|-------|------|
| **Docker** | Moteur de conteneurs, nécessaire pour faire tourner le cluster K3d sur la machine hôte |
| **K3d** | Crée un cluster Kubernetes léger (K3s) à l'intérieur de conteneurs Docker, évitant le besoin de VMs |
| **kubectl** | Client en ligne de commande pour interagir avec l'API Kubernetes (déployer, inspecter, debugger) |
| **Helm** | Gestionnaire de paquets Kubernetes - permet d'installer GitLab via son chart officiel `gitlab/gitlab` avec un seul fichier de valeurs au lieu de dizaines de manifestes YAML |
| **Argo CD CLI** | Client pour Argo CD, le moteur GitOps qui surveille un repo Git et synchronise automatiquement l'état du cluster |
| **git** | Nécessaire pour cloner le projet GitLab local, y pousser les manifestes, et effectuer la démo de changement de version (v1 -> v2) |

## Prérequis

- Docker (accessible sans sudo - `newgrp docker` si nécessaire)
- ~3 CPU, 6 GB RAM minimum pour GitLab

## Installation

### Via le Makefile (recommandé)

```bash
# Pipeline complet
make bonus

# Ou étape par étape
make bonus-install    # Installe Helm + outils P3 si absents
make bonus-setup      # Crée cluster K3d + Argo CD + 3 namespaces
make bonus-gitlab     # Déploie et configure GitLab (~15 min)
make bonus-deploy     # Déploie l'app via Argo CD -> GitLab local
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

## Vérification

```bash
make bonus-test
```

Vérifie :
- Cluster K3d existe
- 3 namespaces : argocd, dev, gitlab
- Pods GitLab en Running
- Pods Argo CD en Running
- App dans dev en Running
- App répond sur port 8888
- Source Argo CD pointe vers GitLab (pas GitHub)

## Accès

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

## Créer un nouveau dépôt et y pousser du code

La grille d'évaluation demande de créer un **nouveau** dépôt pendant la soutenance,
d'y ajouter du code, et de vérifier sur GitLab que l'opération a réussi. Ce dépôt
de démonstration est indépendant de `iot-app`, celui qu'Argo CD synchronise : il
sert uniquement à prouver que l'instance GitLab est pleinement fonctionnelle.

Les deux variantes ci-dessous supposent le port-forward actif :

```bash
kubectl port-forward svc/gitlab-webservice-default -n gitlab 30080:8181 &
GITLAB_PWD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 -d)
echo "root / $GITLAB_PWD"
```

### Variante A - API et git en ligne de commande

```bash
# 1. Jeton d'accès (le même mécanisme que configure_gitlab.sh)
TOOLBOX=$(kubectl get pods -n gitlab -l app=toolbox -o jsonpath='{.items[0].metadata.name}')
TOKEN=$(kubectl exec "$TOOLBOX" -n gitlab -c toolbox -- gitlab-rails runner "
puts User.find_by_username('root').personal_access_tokens.create!(
  scopes: [:api, :read_repository, :write_repository],
  name: 'demo-defense', expires_at: 30.days.from_now).token" | tail -1 | tr -d '\r\n')

# 2. Création du dépôt
curl -s -X POST "http://localhost:30080/api/v4/projects" \
    -H "PRIVATE-TOKEN: $TOKEN" \
    -d "name=demo-defense&visibility=public" | jq '{id, path_with_namespace, web_url}'

# 3. Ajout de code et push
mkdir -p /tmp/demo-defense && cd /tmp/demo-defense && git init -b main
echo 'print("bonjour depuis GitLab local")' > hello.py
git config user.email "root@gitlab.local" && git config user.name "Administrator"
git add . && git commit -m "Ajout de hello.py"
git remote add origin "http://root:${TOKEN}@localhost:30080/root/demo-defense.git"
git push -u origin main

# 4. Vérification côté GitLab : le fichier doit apparaître dans l'arbre du dépôt
curl -s "http://localhost:30080/api/v4/projects/root%2Fdemo-defense/repository/tree" \
    -H "PRIVATE-TOKEN: $TOKEN" | jq '.[].name'
curl -s "http://localhost:30080/api/v4/projects/root%2Fdemo-defense/repository/commits" \
    -H "PRIVATE-TOKEN: $TOKEN" | jq '.[0] | {title, author_name}'
```

### Variante B - interface web

1. Ouvrir `http://localhost:30080` et se connecter avec `root` et le mot de passe récupéré plus haut.
2. **New project** -> **Create blank project** : nom `demo-defense`, visibilité *Public*, cocher
   *Initialize repository with a README*.
3. Dans le dépôt créé : **+** -> **New file**, saisir un fichier (par exemple `hello.py`),
   puis **Commit changes**.
4. Le fichier et le commit apparaissent immédiatement dans l'arborescence du dépôt et dans
   l'onglet **Commits** : l'opération est vérifiée côté GitLab.

> **À tester avant la soutenance.** Le chart est configuré avec
> `global.hosts.domain: gitlab.local` : l'URL externe de GitLab est
> `http://gitlab.gitlab.local`, et certaines redirections (apres connexion
> notamment) peuvent pointer vers ce nom plutôt que vers `localhost:30080`.
> Si le navigateur part sur une adresse injoignable, deux solutions :
> utiliser la variante A, ou faire correspondre les deux noms :
>
> ```bash
> echo "127.0.0.1 gitlab.gitlab.local" | sudo tee -a /etc/hosts
> sudo kubectl port-forward svc/gitlab-webservice-default -n gitlab 80:8181
> # puis http://gitlab.gitlab.local
> ```

### Nettoyage du dépôt de démonstration

```bash
curl -s -X DELETE "http://localhost:30080/api/v4/projects/root%2Fdemo-defense" \
    -H "PRIVATE-TOKEN: $TOKEN"
```

## Démonstration GitOps v1 -> v2

1. **Port-forward vers GitLab** :
   ```bash
   kubectl port-forward svc/gitlab-webservice-default -n gitlab 30080:8181 &
   ```

2. **Récupérer le mot de passe GitLab** :
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

4. **Vérifier** (Argo CD synchronise en ~3 min) :
   ```bash
   curl http://localhost:8888
   # -> v2
   ```

## Flux GitOps

```
Utilisateur push vers GitLab local
  -> Argo CD détecte le changement (polling ~3 min)
    -> Argo CD synchronise les manifestes
      -> Kubernetes déploie la nouvelle version dans dev
```

## Différences avec la Partie 3

| Aspect | Partie 3 | Bonus |
|--------|----------|-------|
| Source Git | GitHub (externe) | GitLab (local, dans le cluster) |
| Namespaces | argocd, dev | argocd, dev, gitlab |
| Outils supplémentaires | - | Helm |
| Ressources | Légères | ~3 CPU, 6 GB RAM (GitLab) |
| Déploiement GitLab | - | Helm chart officiel gitlab/gitlab |

## Configuration GitLab

Le chart Helm est configuré avec des paramètres minimaux (`confs/gitlab-values.yaml`) :
- Pas de cert-manager, nginx-ingress, prometheus, runner, registry, KAS, pages
- Replicas réduites à 1
- HTTP uniquement (pas de TLS)
- Communication Argo CD -> GitLab via DNS interne Kubernetes

### Version du chart épinglée à 9.11.12

`scripts/deploy_gitlab.sh` fixe `CHART_VERSION="9.11.12"` (GitLab 18.11.11).
**Ne pas repasser sur la dernière version publiée**, pour deux raisons :

1. **Le chart 10.0.0 (GitLab 19.0.0) a supprimé les sous-charts PostgreSQL,
   Redis et MinIO groupés.** Il exige désormais une base de données externe.
   Le message du chart est explicite : *"The bundled PostgreSQL chart has been
   removed... Please migrate to an external PostgreSQL"*. 9.11.12 est le
   dernier chart de la série 9.x, qui les fournit encore.

2. **La clé `certmanager.install` n'existe plus depuis le chart 9.0.0**, où
   elle a été remplacée par `installCertmanager` à la racine. `certmanager`
   est devenu l'alias du sous-chart jetstack, dont le schéma de validation
   refuse les clés inconnues : l'ancienne forme fait échouer `helm`.

### Allègement pour poste contraint

Sur un poste de 16 Go, la VM hôte reçoit environ 10 Go et GitLab réclame ~6 Go
à lui seul : la marge est nulle et l'hôte finit par tuer le processus QEMU.
`confs/gitlab-values.yaml` retire donc ce qui ne sert pas au bonus.

Le sujet demande d'héberger un dépôt Git et de laisser Argo CD le lire.
Sauvegardes, métriques Prometheus, réception d'emails et stockage objet n'y
participent pas :

| Composant retiré | Réservation récupérée | Rôle supprimé |
|---|---|---|
| `gitlab.toolbox` | 350 M | sauvegarde et restauration |
| `gitlab.gitlab-exporter` | 100 M | métriques Prometheus |
| `gitlab.mailroom` | 150 M | emails entrants |
| `global.minio` | 128 Mi | stockage objet |

Désactiver MinIO est sans risque ici : tous les usages qui le consommeraient
(`lfs`, `artifacts`, `uploads`, `packages`, `terraformState`) sont déjà coupés,
et `externalDiffs`, `dependencyProxy`, `ciSecureFiles` valent `false` par
défaut. Le `checkConfig` du stockage objet ne se déclenche donc pas. Il fallait
en revanche désactiver `toolbox` en même temps, sinon le chart réclame un
secret de sauvegarde.

Deux réglages agissent sur la mémoire **réellement consommée**, pas seulement
sur les réservations :

- `gitlab.sidekiq.concurrency` passe de 20 à 5. Chaque thread Sidekiq porte son
  propre jeu d'objets Ruby, et le bonus n'a qu'un utilisateur.
- `gitlab.sidekiq.memoryKiller.maxRss` passe de 2 Go à 1 Go : un worker qui
  gonfle est redémarré plus tôt.

Les `resources.requests` de `webservice` (2,5 G -> 1,5 G) et `sidekiq`
(2 G -> 1 G) n'agissent que sur l'ordonnancement : elles évitent des pods
bloqués en `Pending` sur un cluster k3d contraint, sans réduire l'usage réel.

Au total, environ 2,7 Go de réservations libérées et quatre pods en moins.

**Non testé.** La validation demande un déploiement GitLab complet dans la VM.
Si le bonus plante encore, le levier suivant est côté hôte : fermer VS Code,
Chrome et Discord avant `make bonus`, puis monter la VM à `VM_RAM_MB=11264`.

### Images PostgreSQL et Redis redirigées

Bitnami a retiré de Docker Hub tous les tags versionnés de ses images ; seul
`latest` subsiste sous `bitnami/`, le reste a été déplacé sous
`bitnamilegacy/`. Sans redirection, le déploiement part en `ImagePullBackOff`
sur la base et le cache. `confs/gitlab-values.yaml` réécrit donc les huit
images concernées vers `bitnamilegacy/`.

Ces tags correspondent au chart 9.11.12 : **les réajuster si `CHART_VERSION`
change**. `bitnamilegacy` étant une archive présentée comme transitoire, la
solution durable en cas de disparition sera de déployer un PostgreSQL et un
Redis externes (images officielles `postgres` et `redis`) et de renseigner
`global.psql` et `global.redis`.

## Nettoyage

```bash
make bonus-clean    # Supprime le cluster K3d + Docker prune
make fclean         # Nettoyage forcé de tout le projet
```

## Structure des fichiers

```
bonus/
├── README.md
├── scripts/
│   ├── install.sh              # Installe Helm (+ outils P3 si absents)
│   ├── setup_cluster.sh        # Crée cluster K3d + Argo CD + 3 namespaces
│   ├── deploy_gitlab.sh        # Déploie GitLab via Helm chart officiel
│   ├── configure_gitlab.sh     # Crée projet GitLab, push manifestes, enregistre repo dans Argo CD
│   ├── deploy_app.sh           # Applique application.yaml Argo CD -> GitLab local
│   ├── test.sh                 # Vérifie tout (GitLab, Argo CD, app, GitOps)
│   └── cleanup.sh              # Supprime cluster + nettoyage
└── confs/
    ├── gitlab-values.yaml      # Helm values minimaux pour GitLab
    ├── application.yaml        # Argo CD Application -> GitLab local
    ├── deployment.yaml         # Manifeste Kubernetes (wil42/playground:v1)
    ├── service.yaml            # Service ClusterIP port 8888
    └── ingress.yaml            # Ingress Traefik
```
