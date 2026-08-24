# Partie 1 - K3s et Vagrant

## Description

Cette partie met en place un cluster Kubernetes K3s distribué sur 2 machines virtuelles utilisant Vagrant, avec une architecture controller/worker.

## Architecture

### Machines Virtuelles

- **chillionS** (Server/Controller)
  - IP : `192.168.56.110`
  - Rôle : K3s Server (mode controller)
  - Ressources : 1 CPU, 1024 MB RAM
- **chillionSW** (Server Worker)
  - IP : `192.168.56.111`
  - Rôle : K3s Agent (mode worker)
  - Ressources : 1 CPU, 1024 MB RAM

### Configuration réseau

- Réseau privé : `192.168.56.0/24`
- Interface réseau : seconde interface créée par `private_network`. Son nom
  depend de la distribution (`enp0s8` sur Debian 13, `eth1` sur des boxes
  plus anciennes) : les scripts la déduisent de l'IP au lieu de la coder en dur.
  Pour l'afficher pendant l'évaluation : `ip a`
- Communication SSH sans mot de passe configurée

## Conformité aux consignes

### Exigences respectées

1. **Noms des machines** :

   - `chillionS` (login + S pour Server)
   - `chillionSW` (login + SW pour ServerWorker)

2. **Adresses IP** :

   - Server : `192.168.56.110`
   - Worker : `192.168.56.111`

3. **Ressources** :

   - 1 CPU par machine
   - 1024 MB RAM (dans la limite recommandée 512-1024 MB)

4. **SSH sans mot de passe** :

   - Clé générée par Vagrant, insérée automatiquement dans chaque VM
   - `vagrant ssh chillionS` / `vagrant ssh chillionSW` sans mot de passe

5. **K3s Installation** :

   - Mode controller sur chillionS
   - Mode agent sur chillionSW
   - kubectl installé et configuré

6. **Distribution** :
   - Debian 13 "Trixie" (`bento/debian-13`) - derniere version stable de Debian

## Structure des fichiers

```
p1/
├── Vagrantfile                    # Configuration des VMs
├── scripts/
│   ├── install_k3s_server.sh    # Installation K3s controller
│   └── install_k3s_agent.sh     # Installation K3s agent
└── confs/                        # node-token publié par le server (ignoré par git)
```

## Installation et déploiement

### Prérequis

- VirtualBox installé
- Vagrant installé
- Au moins 2 GB de RAM disponible

### Commandes de déploiement

```bash
# Depuis le dossier iot/
make p1

# Ou directement
cd p1 && vagrant up
```

### Ordre de démarrage

1. **chillionS** : Installation du serveur K3s
2. **chillionSW** : Installation de l'agent et connexion au cluster

## Vérification du cluster

### Via Makefile

```bash
# Statut des VMs
make p1-status

# Connexion SSH au serveur
make p1-ssh

# Vérification du cluster
make p1-up  # Affiche automatiquement l'état des nodes
```

### Commandes manuelles

```bash
# SSH vers le serveur
cd p1 && vagrant ssh chillionS

# Vérifier les nodes du cluster
kubectl get nodes -o wide

# Vérifier les pods système
kubectl get pods -A

# Informations sur le cluster
kubectl cluster-info
```

### Résultat attendu

```bash
$ kubectl get nodes -o wide
NAME        STATUS   ROLES                  AGE   VERSION        INTERNAL-IP       EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
chillions   Ready    control-plane,master   2m    v1.3x.x+k3s1   192.168.56.110   <none>        Debian GNU/Linux 13   6.x-amd64      containerd://2.x-k3s1
chillionsw  Ready    <none>                 1m    v1.3x.x+k3s1   192.168.56.111   <none>        Debian GNU/Linux 13   6.x-amd64      containerd://2.x-k3s1
```

## Fonctionnalités techniques

### K3s Server (chillionS)

- **API Server** : Accessible sur `192.168.56.110:6443`
- **Datastore** : SQLite intégré (via kine), et non etcd : c'est le stockage par défaut de K3s en mode serveur unique
- **Controller Manager** : Gestion des ressources
- **Scheduler** : Placement des pods
- **Traefik Ingress** : Contrôleur d'ingress par défaut

### K3s Agent (chillionSW)

- **kubelet** : Agent de node
- **kube-proxy** : Proxy réseau
- **containerd** : Runtime de conteneurs
- **Flannel** : CNI pour le réseau pods

### Configuration réseau

- **CNI** : Flannel (par défaut avec K3s)
- **Service CIDR** : `10.43.0.0/16`
- **Cluster CIDR** : `10.42.0.0/16`
- **Interface** : seconde interface du réseau privé Vagrant (`enp0s8` sur
  Debian 13), detectee a partir de l'IP et passee a `--flannel-iface`

## Gestion du cluster

### Arrêt et redémarrage

```bash
# Arrêt des VMs
make p1-down
cd p1 && vagrant halt

# Redémarrage
make p1-up
cd p1 && vagrant up

# Destruction complète
make p1-clean
cd p1 && vagrant destroy -f
```

### Debugging et logs

```bash
# Logs K3s server
vagrant ssh chillionS -c "sudo journalctl -u k3s -f"

# Logs K3s agent
vagrant ssh chillionSW -c "sudo journalctl -u k3s-agent -f"

# État des services
vagrant ssh chillionS -c "sudo systemctl status k3s"
vagrant ssh chillionSW -c "sudo systemctl status k3s-agent"
```

## Sécurité

### Configuration SSH

- Clé SSH générée par Vagrant et insérée à la création de chaque VM
  (pas de clé « insecure » partagée entre les machines)
- Connexion sans mot de passe via `vagrant ssh`

### Token K3s

- Token généré par le serveur K3s à l'installation
- Publié dans `/vagrant/confs/node-token` (dossier synchronisé, ignoré par git)
- Lu par l'agent au provisionnement : aucun secret en dur, aucun canal SSH
  inter-VM à maintenir

### Firewall

`ufw` est inactif par défaut sur la box utilisée : aucun filtrage n'est appliqué
entre les deux machines. Les scripts se contentent d'autoriser explicitement les
ports indispensables, au cas où le pare-feu serait activé sur la machine hôte
d'évaluation :

- Port 22 (SSH) sur les deux machines
- Port 6443 (API Kubernetes) sur le server

Si `ufw` devait être activé, il faudrait ouvrir en plus le port 8472/UDP (VXLAN
flannel) et le port 10250/TCP (kubelet), sans quoi le trafic inter-nodes et les
commandes `kubectl logs` / `kubectl exec` cesseraient de fonctionner.

## Tests et validation

### Test de base

```bash
# Depuis le host
cd p1
vagrant ssh chillionS -c "kubectl get nodes"

# Vérification de la connectivité
vagrant ssh chillionS -c "kubectl get pods -n kube-system"
```

### Test avancé

```bash
# Déploiement d'un pod de test
vagrant ssh chillionS -c "kubectl run test-pod --image=nginx --restart=Never"
vagrant ssh chillionS -c "kubectl get pods"
vagrant ssh chillionS -c "kubectl delete pod test-pod"
```

