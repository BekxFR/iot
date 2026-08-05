# Points Importants des Consignes - Projet IoT

Ce document détaille tous les points cruciaux des consignes pour s'assurer du respect des exigences du projet Inception-of-Things.

## Vue d'ensemble du projet

### Objectif général
- **Nom** : Inception-of-Things (IoT)
- **Type** : Exercice d'administration système avec Kubernetes
- **Approche** : Progressive en 3 parties (K3s -> Applications -> GitOps)

### Structure obligatoire
```
iot/
├── p1/           # Partie 1 : K3s et Vagrant
├── p2/           # Partie 2 : K3s et trois applications
├── p3/           # Partie 3 : K3d et Argo CD
└── bonus/        # Partie bonus (optionnelle)
```

## Partie 1 : K3s et Vagrant

### Exigences obligatoires

#### Machines virtuelles
- **Nombre** : Exactement 2 machines
- **Distribution** : Version stable la plus récente (Ubuntu 26.04 LTS, box `bento/ubuntu-26.04`)
- **Ressources minimales** : 
  - 1 CPU par machine
  - 512 MB ou 1024 MB de RAM (1024 MB choisi)

#### Nommage des machines
- **Première machine** : `[LOGIN]S` (ex: `chillionS`)
  - Rôle : Server/Controller
- **Deuxième machine** : `[LOGIN]SW` (ex: `chillionSW`)
  - Rôle : ServerWorker/Agent

#### Configuration réseau
- **IP première machine** : `192.168.56.110` (fixe)
- **IP deuxième machine** : `192.168.56.111` (fixe)
- **Interface** : Réseau privé dédié
- **SSH** : Connexion sans mot de passe obligatoire

#### Installation K3s
- **Première machine** : Mode controller (serveur)
- **Deuxième machine** : Mode agent (worker)
- **kubectl** : Installé et configuré

### Points de validation
- [ ] 2 VMs avec les bons noms
- [ ] IPs fixes correctes
- [ ] SSH sans mot de passe
- [ ] K3s controller fonctionnel
- [ ] K3s agent connecté au cluster
- [ ] `kubectl get nodes` affiche les 2 nodes

## Partie 2 : K3s et trois applications

### Exigences obligatoires

#### Machine virtuelle
- **Nombre** : 1 seule machine
- **Nom** : `[LOGIN]S` (ex: `chillionS`)
- **IP** : `192.168.56.110`
- **K3s** : Mode serveur uniquement

#### Applications web
- **Nombre** : Exactement 3 applications
- **Type** : Applications web de votre choix
- **Accès** : Via header HOST sur l'IP `192.168.56.110`

#### Routing obligatoire
- **Host: app1.com** -> Application 1
- **Host: app2.com** -> Application 2  
- **Accès direct IP** -> Application 3 (par défaut)

#### Configuration spéciale
- **Application 2** : Doit avoir exactement 3 replicas
- **Ingress** : Doit être configuré (ne pas l'afficher pendant l'évaluation)

### Points de validation
- [ ] 1 VM avec K3s serveur
- [ ] 3 applications web déployées
- [ ] Routing par HOST fonctionnel
- [ ] App2 avec 3 replicas
- [ ] Tests curl fonctionnels :
  ```bash
  curl -H "Host: app1.com" http://192.168.56.110
  curl -H "Host: app2.com" http://192.168.56.110
  curl http://192.168.56.110
  ```

## Partie 3 : K3d et Argo CD

### Exigences obligatoires

#### Environnement
- **K3d** : Au lieu de Vagrant (comprendre la différence)
- **Docker** : Requis pour K3d
- **Script d'installation** : Obligatoire pour tous les outils

#### Namespaces obligatoires
- **argocd** : Dédié à Argo CD
- **dev** : Contient l'application déployée

#### Repository GitHub
- **Type** : Repository public obligatoire
- **Nom** : Doit contenir le login d'un membre de l'équipe
- **Contenu** : Fichiers de configuration Kubernetes
- **Usage** : Source pour le déploiement GitOps

#### Application
- **Options** :
  - Utiliser `wil42/playground` (recommandé)
  - Ou créer sa propre application
- **Versions** : Exactement 2 versions (v1 et v2)
- **Port** : 8888 obligatoire
- **Tags** : v1 et v2 pour les versions

#### GitOps fonctionnel
- **Déploiement automatique** : Depuis le repository GitHub
- **Changement de version** : Via modification Git
- **Synchronisation** : Argo CD doit synchroniser automatiquement

### Points de validation
- [ ] K3d installé et fonctionnel
- [ ] Script d'installation complet
- [ ] 2 namespaces créés (argocd + dev)
- [ ] Repository GitHub public avec login
- [ ] Application accessible sur port 8888
- [ ] Test changement v1 -> v2 via Git
- [ ] Démonstration GitOps pendant l'évaluation

### Démonstration obligatoire pendant l'évaluation
```bash
# État initial
curl http://localhost:8888
# Réponse: {"status":"ok", "message": "v1"}

# Changement dans Git
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' deployment.yaml
git add deployment.yaml
git commit -m "Update to v2"
git push origin main

# Vérification après synchronisation
curl http://localhost:8888
# Réponse: {"status":"ok", "message": "v2"}
```

## Partie Bonus (optionnelle)

### Exigences
- **GitLab local** : Instance GitLab qui fonctionne localement
- **Integration cluster** : GitLab configuré avec votre cluster
- **Namespace** : `gitlab` dédié
- **Compatibilité** : Tout ce qui fonctionne en Partie 3 doit fonctionner avec GitLab

### Conditions
- **Prérequis** : Partie obligatoire parfaite et sans erreur
- **Évaluation** : Bonus évalué seulement si tout le reste est parfait

## Points critiques pour l'évaluation

### Différence K3s vs K3d
| Aspect | K3s | K3d |
|--------|-----|-----|
| **Déploiement** | Sur VM/serveur physique | Dans containers Docker |
| **Ressources** | Plus de ressources | Léger, rapide |
| **Persistance** | Données persistantes | Éphémère (pour dev/test) |
| **Cas d'usage** | Production, environnements durables | Développement, CI/CD, tests |
| **Networking** | Host network direct | Docker network |
| **Démarrage** | Plus lent (VM) | Très rapide (containers) |

### Structure de repository attendue
```
find -maxdepth 2 -ls
./p1
./p1/Vagrantfile
./p1/scripts
./p1/confs
./p2
./p2/Vagrantfile
./p2/scripts
./p2/confs
./p3
./p3/scripts
./p3/confs
```

### Fichiers obligatoires
- **Scripts** : Dans dossier `scripts/`
- **Configurations** : Dans dossier `confs/`
- **Documentation** : README dans chaque partie

## Erreurs à éviter

### Partie 1
- Mauvais nommage des machines
- IPs incorrectes
- SSH avec mot de passe
- K3s non fonctionnel

### Partie 2
- Plus ou moins de 3 applications
- Routing HOST incorrect
- App2 sans 3 replicas
- Ingress affiché pendant l'évaluation

### Partie 3
- Pas de script d'installation
- Repository GitHub privé
- Application non accessible port 8888
- GitOps non fonctionnel
- Pas de démonstration v1->v2

## Documentation et ressources

### Lectures recommandées
- Documentation K3s officielle
- Guide K3d
- Documentation Argo CD
- Concepts Kubernetes de base

### Commandes essentielles à maîtriser
```bash
# Vagrant
vagrant up/down/destroy/ssh/status

# Kubernetes
kubectl get nodes/pods/svc/ingress
kubectl apply/delete -f
kubectl port-forward

# K3d
k3d cluster create/delete/list
k3d node list

# Argo CD
argocd app list/sync/get
```

## Checklist finale

### Avant l'évaluation
- [ ] Toutes les parties fonctionnent indépendamment
- [ ] Scripts testés et fonctionnels
- [ ] Documentation à jour
- [ ] Repository GitHub configuré (P3)
- [ ] Démonstration GitOps préparée
- [ ] Différence K3s/K3d comprise
- [ ] Structure de fichiers respectée

### Pendant l'évaluation
- [ ] Expliquer l'architecture de chaque partie
- [ ] Démontrer les fonctionnalités demandées
- [ ] Répondre aux questions techniques
- [ ] Montrer la compréhension des concepts
- [ ] Effectuer la démonstration GitOps

