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
