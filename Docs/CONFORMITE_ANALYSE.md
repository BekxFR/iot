# Analyse de conformite - Inception-of-Things

Date: 2026-08-03
Reference: Docs/iot.en.subject.pdf (v4.0)

## Partie 1 : K3s et Vagrant - CONFORME

- [x] 2 machines via Vagrant (chillionS + chillionSW)
- [x] Hostnames = login + S / SW, noms VirtualBox identiques
- [x] IPs : 192.168.56.110 (server), 192.168.56.111 (worker)
- [x] Derniere version stable de la distribution : Ubuntu 26.04 LTS (`bento/ubuntu-26.04`)
- [x] SSH sans mot de passe (cle generee et inseree par Vagrant)
- [x] 1 CPU, 1024 MB RAM
- [x] K3s server en mode controller
- [x] K3s agent en mode agent
- [x] kubectl installe et configure
- [x] Dossier `p1/confs/` present (recoit le node-token publie par le server)

## Partie 2 : K3s et 3 applications - CONFORME

- [x] 1 seule VM (llarreyS), IP 192.168.56.110, Ubuntu 26.04 LTS
- [x] K3s en mode server
- [x] 3 applications web (app1, app2, app3)
- [x] Routage HOST : app1.com -> app1, app2.com -> app2, defaut -> app3
- [x] app2 avec 3 replicas
- [x] Objets crees dans le namespace `default` : `kubectl get all` (sans option,
      comme dans la grille) affiche les 3 deployments, pods et services
- [x] Ingress Traefik avec `ingressClassName: traefik`
- [x] Dossiers `scripts/` et `confs/` presents

## Partie 3 : K3d et Argo CD - CONFORME

- [x] K3d installe (pas de Vagrant)
- [x] Script d'installation complet (Docker, kubectl, K3d, Argo CD CLI), Debian et Ubuntu
- [x] 2 namespaces : argocd + dev
- [x] Argo CD installe dans le namespace argocd
- [x] Application deployee dans le namespace dev
- [x] Repo GitHub public avec le login d'un membre du groupe (BekxFR/trobert-iot-argocd-app)
- [x] Image wil42/playground avec versions v1 et v2
- [x] Application accessible sur http://localhost:8888 (port hote 8888 -> entrypoint HTTP du loadbalancer K3d -> Ingress Traefik)
- [x] application.yaml avec syncPolicy automated (prune + selfHeal)
- [x] Argo CD synchronise automatiquement depuis le repo GitHub

## Bonus : GitLab local sur K3d - CONFORME

- [x] GitLab deploye dans le cluster K3d (namespace gitlab)
- [x] Helm chart officiel gitlab/gitlab, derniere version disponible
- [x] 3 namespaces : argocd, dev, gitlab
- [x] Argo CD synchronise depuis le GitLab local (pas GitHub)
- [x] URL interne : http://gitlab-webservice-default.gitlab.svc.cluster.local:8181
- [x] Application wil42/playground dans le namespace dev, port 8888
- [x] Repo secret Argo CD avec insecure: "true" (pas de TLS)
- [x] Scripts automatises : install, setup, deploy_gitlab, configure_gitlab, deploy_app, test, cleanup
- [x] GitOps v1 -> v2 demontrable via le GitLab local
- [x] Makefile avec cibles bonus

## Structure globale

- [x] Dossiers p1/, p2/, p3/, bonus/ a la racine
- [x] Scripts dans scripts/
- [x] Configs dans confs/ (y compris p1)

---

## Points de vigilance pour la soutenance

### 1. Le depot GitHub fait foi pour la partie 3

Argo CD applique les manifests du depot `BekxFR/trobert-iot-argocd-app`, pas
ceux de `p3/confs/`. Toute modification locale doit y etre repercutee.

### 2. Demonstration du changement de version

1. `curl http://localhost:8888` -> v1
2. Modifier deployment.yaml dans le depot : v1 -> v2
3. `git push`
4. Argo CD synchronise automatiquement (sync auto toutes les 3 minutes,
   ou bouton REFRESH / `argocd app sync` pour ne pas attendre)
5. `curl http://localhost:8888` -> v2

### 3. Acces a l'interface Argo CD

Le service `argocd-server` reste en ClusterIP. Un service de type LoadBalancer
entrerait en conflit avec Traefik, qui occupe deja les ports 80 et 443 des
nodes. L'acces se fait par port-forward :

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

### 4. Stockage des VM Vagrant

Par defaut le Makefile stocke les box et les disques dans `/tmp/chillion`.
Si `/tmp` est monte en tmpfs (RAM) ou trop petit sur la machine d'evaluation :

```
make VM_STORAGE=$HOME/iot-vms p1
```

### 5. Virtualisation imbriquee

Les parties 1 et 2 lancent des VM VirtualBox a l'interieur de la VM
d'evaluation : VT-x / AMD-V doit y etre expose. `Tools/VM_commands.sh` le
verifie et le signale.
