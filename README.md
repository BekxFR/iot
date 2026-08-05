# Inception-of-Things (IoT)

Ceci est un exercice d'administration système/Kubernetes divisé en parties pour découvrir Vagrant et déployer des clusters Kubernetes.

## Structure du Projet

```
iot/
├── p1/                          # Partie 1 : K3s et Vagrant
├── p2/                          # Partie 2 : K3s et trois applications  
├── p3/                          # Partie 3 : K3d et Argo CD
├── Docs/                        # Fichiers de documentation
│   ├── CONSIGNES_POINTS_CLES.md # Exigences détaillées
│   └── GITIGNORE_INFO.md        # Explications du .gitignore
├── Tools/                       # Scripts utilitaires
│   ├── cleanup.sh               # Nettoie les fichiers temporaires
│   ├── check_requirements.sh    # Vérifie la conformité
│   └── VM_commands.sh           # Aide pour la gestion des VMs
├── Makefile                     # Commandes d'automatisation
├── .gitignore                   # Fichiers à ignorer
└── README.md                    # Ce fichier
```

## Démarrage Rapide

```bash
# Partie 1 : K3s + Vagrant (2 VMs)
make p1

# Partie 2 : K3s + Applications Web (1 VM)
make p2

# Partie 3 : K3d + Argo CD (Docker)
make p3

# Tout nettoyer
make clean
```

## Gestion des Fichiers

### Fichiers Ignorés (.gitignore)
Le projet inclut un `.gitignore` complet qui exclut :
- Fichiers générés par Vagrant (`.vagrant/`, `*.box`)
- Fichiers de configuration Kubernetes (`kubeconfig`, secrets)
- Données temporaires Docker/K3d
- Logs d'applications et fichiers de debug
- Configurations d'éditeurs
- Fichiers temporaires système

### Script de Nettoyage
```bash
./Tools/cleanup.sh  # Supprime tous les fichiers générés et données temporaires
```

## Documentation

### Lecture Essentielle
- **[Documentation technique complète](Docs/index.html)** - Toutes les notions du projet au format web : virtualisation, Kubernetes, K3s, K3d, GitOps, Helm, choix techniques, runbook, dépannage et lexique. Bulles d'information sur chaque acronyme. Ouvrir avec `xdg-open Docs/index.html`
- **[Points Clés des Consignes](Docs/CONSIGNES_POINTS_CLES.md)** - Exigences détaillées et points critiques pour l'évaluation
- **[Informations .gitignore](Docs/GITIGNORE_INFO.md)** - Fichiers ignorés et gestion du repository

### Documentation par Partie
Chaque partie a sa propre documentation détaillée :
- [Documentation Partie 1](p1/README.md) - K3s et Vagrant
- [Documentation Partie 2](p2/README.md) - K3s et Applications
- [Documentation Partie 3](p3/README.md) - K3d et Argo CD

### Référence Rapide
- **Partie 1** : 2 VMs (chillionS + chillionSW), cluster K3s, IPs 192.168.56.110-111
- **Partie 2** : 1 VM, 3 applications web, routage par en-tête HOST, app2 avec 3 replicas
- **Partie 3** : cluster K3d, Argo CD, GitOps avec GitHub, port 8888
