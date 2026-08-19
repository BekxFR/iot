# Documentation Directory

Ce répertoire contient la documentation détaillée du projet IoT.

## Documentation web complète

### `index.html`

**Point d'entrée recommandé.** Documentation technique complète au format web :
notions (virtualisation, conteneurs, Kubernetes, K3s, K3d, GitOps, Helm),
architecture déployée, choix techniques justifiés, runbook, dépannage et lexique
de 109 entrées.

Chaque acronyme du texte affiche sa signification au survol et renvoie au lexique.
Page autonome, sans dépendance réseau : elle s'ouvre par un simple double-clic.

```bash
xdg-open Docs/index.html    # ou : firefox Docs/index.html
```

## Documents disponibles

### `CONSIGNES_POINTS_CLES.md`
**Document principal pour l'évaluation**

Points critiques et exigences pour chaque partie :
- Structure obligatoire des fichiers
- Configurations requises
- Points de vérification
- Checklist de conformité

### `GRILLE_SOUTENANCE.md`
**Document a suivre le jour de la defense**

Reprise point par point de la grille d'evaluation de l'intra (`iot.html`) :
- Pour chaque question : ce que l'evaluateur verifie, la commande exacte a lancer,
  la preuve correspondante dans le depot, ce qu'il faut savoir expliquer
- Ordre de passage impose par les conflits de ressources (noms de VM, ports, RAM)
- Reponses preparees pour les questions orales (K3s, Vagrant, K3d, CI et Argo CD)
- Preparation la veille et checklist finale

### `MIGRATION_QEMU.md`
**VM hote sous QEMU/KVM au lieu de VirtualBox**

Migration de la VM hote pour debloquer la double imbrication sur CPU Intel recents :
- Ou se trouvent les fichiers de la VM utilises par QEMU
- Comment lancer la VM, par script ou en ligne de commande QEMU detaillee
- Les etapes restant a faire dans l'invite (reseau, Guest Additions, disque)
- Depannage et retour arriere vers VirtualBox

Le script associe se trouve dans ce meme repertoire : `migrate-vbox-to-qemu.sh`.

### `GITIGNORE_INFO.md`
**Explication du fichier .gitignore**

Fichiers et répertoires ignorés :
- Fichiers temporaires Vagrant
- Données Docker/K3d
- Configurations Kubernetes sensibles
- Logs et caches

## Accès rapide

- Via Makefile : `make help` affiche les liens vers cette documentation
- Depuis le README principal : liens directs vers chaque document
- Structure visible avec : `tree Docs/` ou `ls -la Docs/`
