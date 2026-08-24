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
- Lancement par interface graphique (virt-manager) ou en ligne de commande
- Precautions de stockage sur le SSD externe
- Depannage et retour arriere vers VirtualBox

Fichiers associes dans ce meme repertoire :
`migrate-vbox-to-qemu.sh` (script) et `Debian-VM.libvirt.xml` (definition
de la VM pour virt-manager).

Le script associe se trouve dans ce meme repertoire : `migrate-vbox-to-qemu.sh`.

### `create-vm-qemu.sh`
**Creer une VM QEMU pour le projet, a partir d'un ISO**

Script autonome destine a quelqu'un qui part de zero, sans VM existante. Il
cree le disque, lance l'installation depuis l'image ISO, puis redemarre la VM
sur son disque.

```bash
./Docs/create-vm-qemu.sh create --iso debian-13-netinst.iso   # creer et installer
./Docs/create-vm-qemu.sh run                                  # lancer une VM existante
./Docs/create-vm-qemu.sh list                                 # lister les VM
./Docs/create-vm-qemu.sh --help                               # toutes les options
```

Plusieurs VM peuvent cohabiter dans le meme dossier, distinguees par `--name`.
Sans verbe, le mode est deduit : `create` si le disque n'existe pas, `run`
sinon, et le mode retenu est affiche avant le lancement.

Il verifie les prerequis (KVM, acces a `/dev/kvm`, virtualisation imbriquee),
dimensionne la VM sur la RAM reelle du poste, et redirige les ports utiles au
projet : 2222 (SSH), 8888 et 8443 (ingress Traefik), 8080 (Argo CD) et 30080
(interface web GitLab du bonus).

A ne pas confondre avec `migrate-vbox-to-qemu.sh`, qui convertit une VM
VirtualBox **existante** au lieu d'en installer une neuve.

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
