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

## Exclusivité entre les parties

Les parties se disputent trois ressources. Le Makefile les libère
automatiquement, sans jamais rien détruire :

| Ressource partagée | Parties | Résolution automatique |
|---|---|---|
| IP `192.168.56.110` | p1 (`chillionS`) et p2 (`llarreyS`) | `p1-up` dépend de `p2-down`, `p2-up` dépend de `p1-down` (`vagrant halt`) |
| Ports hôte 8888 / 8443 / 6550 | p3 (`iot-cluster`) et bonus (`iot-bonus`) | `p3-setup` dépend de `bonus-down`, `bonus-setup` dépend de `p3-down` (`k3d cluster stop`) |
| RAM (~6 Go pour GitLab) | bonus contre p1 et p2 | `bonus-setup` dépend aussi de `p1-down` et `p2-down` |

Les noms de VM diffèrent volontairement entre p1 et p2 (logins de deux membres
du groupe) : VirtualBox refuse deux machines du même nom, donc les deux parties
peuvent coexister et il ne reste que le conflit d'IP, qu'un simple arrêt résout.
