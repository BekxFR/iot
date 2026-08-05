# Fichiers et dossiers ignorés par Git

Ce document liste les principaux fichiers/dossiers ignorés par le `.gitignore` du projet IoT.

## Vagrant (Parties 1 et 2)
- `.vagrant/` - Métadonnées Vagrant
- `*.box` - Images Vagrant téléchargées
- `vagrant.log` - Logs de Vagrant

## Kubernetes (Toutes parties)
- `kubeconfig*` - Fichiers de configuration kubectl
- `*-secret.yaml` - Secrets extraits
- `*.crt`, `*.key`, `*.pem` - Certificats

## Docker/K3d (Partie 3)
- `k3d-*` - Fichiers temporaires K3d
- `*.tar` - Images Docker exportées

## Argo CD (Partie 3)
- `argocd-password.txt` - Mots de passe extraits
- `.argocd/` - Configuration locale

## Logs et Debug
- `*.log` - Tous les logs
- `logs/`, `.logs/` - Dossiers de logs
- `debug/` - Fichiers de debug

## Système
- `.DS_Store` - Fichiers macOS
- `*~` - Fichiers de backup éditeur
- `*.tmp`, `*.temp` - Fichiers temporaires

## Éditeurs
- `.vscode/` - Configuration VS Code
- `.idea/` - Configuration IntelliJ
- `*.swp`, `*.swo` - Fichiers Vim

## Environnement
- `.env*` - Variables d'environnement
- `config.local` - Configurations locales

## Test/Demo
- `test-repo/` - Repositories de test GitOps
- `demo-secrets/` - Secrets de démonstration

## Données persistantes
- `data/`, `db/` - Données de base
- `*-data/` - Volumes de données
- `cache/`, `.cache/` - Cache

## Exemple d'utilisation

```bash
# Voir les fichiers ignorés
git status --ignored

# Forcer l'ajout d'un fichier ignoré (si nécessaire)
git add -f fichier-ignore.log

# Nettoyer les fichiers temporaires
./cleanup.sh
make cleanup-files
```
