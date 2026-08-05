# Tools Directory

Ce répertoire contient les scripts utilitaires pour le projet IoT.

## Scripts disponibles

### `cleanup.sh`
Script de nettoyage complet qui supprime tous les fichiers temporaires générés par :
- Vagrant (boxes, states, logs)
- Docker/K3d (containers, images, volumes)
- Kubernetes (configs, secrets)
- Logs et caches divers

**Usage :**
```bash
./Tools/cleanup.sh
# ou via Makefile
make cleanup-files
```

### `check_requirements.sh`
Script de vérification de conformité aux consignes du projet.
Vérifie la structure, les configurations et les prérequis système.

**Usage :**
```bash
./Tools/check_requirements.sh
# ou via Makefile
make check
```

### `VM_commands.sh`
Scripts d'aide pour la gestion des VMs Vagrant.

**Usage :**
```bash
./Tools/VM_commands.sh
```

## Intégration Makefile

Tous ces scripts sont intégrés dans le Makefile principal :
- `make cleanup-files` -> `./Tools/cleanup.sh`
- `make check` -> `./Tools/check_requirements.sh`
