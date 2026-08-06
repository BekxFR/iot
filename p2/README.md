# Partie 2 - K3s et Applications Web

## Description

Cette partie implémente un cluster K3s avec 3 applications web accessibles via différents hosts.

## Architecture

- **Machine unique** : `llarreyS` (192.168.56.110)
- **K3s** en mode server
- **3 applications web** :
  - App1 : accessible via `app1.com` (1 replica)
  - App2 : accessible via `app2.com` (3 replicas)
  - App3 : application par défaut (1 replica)

## Routing

L'Ingress Traefik route les requêtes selon l'host :

- `Host: app1.com` -> App1
- `Host: app2.com` -> App2
- Accès direct IP -> App3 (par défaut)

## Structure des fichiers

```
p2/
├── Vagrantfile                    # Configuration Vagrant
├── scripts/
│   ├── install_k3s.sh            # Installation K3s
│   ├── setup_apps.sh             # Déploiement applications
│   └── test_apps.sh              # Tests de vérification
└── confs/
    ├── app1-deployment.yaml      # App1 (1 replica)
    ├── app1-service.yaml         # Service App1
    ├── app2-deployment.yaml      # App2 (3 replicas)
    ├── app2-service.yaml         # Service App2
    ├── app3-deployment.yaml      # App3 (par défaut)
    ├── app3-service.yaml         # Service App3
    └── ingress.yaml              # Configuration Ingress

```

## Déploiement

```bash
# Depuis le dossier iot/
make p2
# ou
cd p2 && vagrant up
```

## Tests

```bash
# Test app1.com
curl -H "Host: app1.com" http://192.168.56.110

# Test app2.com
curl -H "Host: app2.com" http://192.168.56.110

# Test application par défaut
curl http://192.168.56.110

# Script de test automatique
cd p2 && vagrant ssh llarreyS -c "/vagrant/scripts/test_apps.sh"
```

## Vérification

Les trois applications sont déployées dans le namespace `default` : c'est ce que
montre la sortie de référence du sujet, et `kubectl get all` affiche donc
directement les 3 deployments, leurs pods et leurs services (app2 en 3/3).

```bash
cd p2 && vagrant ssh llarreyS -c "kubectl get nodes -o wide"
cd p2 && vagrant ssh llarreyS -c "kubectl get all"
cd p2 && vagrant ssh llarreyS -c "kubectl get ingress"
```
