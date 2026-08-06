# Grille de soutenance - Inception-of-Things

Reprise point par point de la grille d'evaluation de l'intra (`Docs/iot.html`).
Pour chaque question : ce que l'evaluateur verifie, la commande exacte a lancer,
la preuve correspondante dans le depot, ce qu'il faut savoir expliquer, et les
pieges qui font echouer la validation.

Source : grille intra du projet Inception-of-Things (sections `Preliminaries`,
`General instructions`, `Mandatory part`, `Bonus`).

---

## Sommaire

- [Ordre de passage impose par les ressources](#ordre-de-passage-impose-par-les-ressources)
- [Q0 - Preliminaires](#q0---preliminaires)
- [Q1 - General instructions](#q1---general-instructions)
- [Q2 - Configuration globale et explications](#q2---configuration-globale-et-explications)
- [Q3 - Partie 1 : Configuration](#q3---partie-1--configuration)
- [Q4 - Partie 1 : Usage](#q4---partie-1--usage)
- [Q5 - Partie 2 : Configuration](#q5---partie-2--configuration)
- [Q6 - Partie 2 : Usage](#q6---partie-2--usage)
- [Q7 - Partie 3 : Configuration](#q7---partie-3--configuration)
- [Q8 - Partie 3 : Usage](#q8---partie-3--usage)
- [Q9 - Bonus](#q9---bonus)
- [Flags et conclusion](#flags-et-conclusion)
- [Preparation la veille](#preparation-la-veille)
- [Checklist finale](#checklist-finale)

---

## Ordre de passage impose par les ressources

Les parties se disputent trois ressources. Ce n'est pas dans la grille, mais cela
ferait planter la soutenance. **Le Makefile libere ces ressources tout seul, et
sans jamais rien detruire** : il se contente d'arreter ce qui gene.

| Ressource partagee | Parties concernees | Ce que le Makefile fait automatiquement |
|---|---|---|
| IP `192.168.56.110` (imposee par le sujet pour p1 **et** p2) | p1 (`chillionS`) et p2 (`llarreyS`) | `make p1` depend de `p2-down`, `make p2` depend de `p1-down` : la VM de l'autre partie est **arretee** (`vagrant halt`). |
| Ports hote `8888`, `8443`, `6550` | p3 (`iot-cluster`) et bonus (`iot-bonus`) | `make p3` depend de `bonus-down`, `make bonus` depend de `p3-down` : le cluster de l'autre partie est **arrete** (`k3d cluster stop`). |
| RAM (~6 Go pour GitLab) | bonus contre p1 et p2 | `bonus-setup` depend aussi de `p1-down` et `p2-down`. |

**Les noms de VM different volontairement entre p1 et p2** : `chillionS` d'un
cote (`p1/Vagrantfile:7`), `llarreyS` de l'autre (`p2/Vagrantfile:7`), soit les
logins de deux membres du groupe. Le sujet impose seulement "un login d'un membre
du groupe suivi de S", donc les deux sont conformes. L'interet est direct :
VirtualBox refuse deux machines du meme nom, donc avec des noms distincts les
deux parties peuvent coexister sur le disque. Il ne reste que le conflit d'IP,
qui n'existe que si les deux VM tournent **en meme temps** : un simple arret
suffit.

Consequence pratique pendant la defense : **rien n'est perdu**. Si l'evaluateur
veut revenir sur la partie 1 apres avoir vu la partie 2, `make p1` rallume la VM
existante en quelques secondes, sans reprovisionner et sans retelecharger la box.
Meme chose pour les clusters K3d avec `k3d cluster start`.

**Sequence de defense recommandee :**

```
make p1        # ~8 min   -> Q3, Q4
make p2        # ~8 min   -> Q5, Q6   (arrete p1 automatiquement)
make p3        # ~5 min   -> Q7, Q8
make bonus     # ~25 min  -> Q9       (arrete iot-cluster et les VM)
```

Le bonus se lance forcement en dernier : il ne peut pas tourner en tache de fond
pendant p3, les deux clusters se disputant les memes ports. Prevenir l'evaluateur
que GitLab met 15 a 20 minutes a demarrer.

**A expliquer si l'evaluateur le remarque** : le choix de deux logins differents
n'est pas cosmetique. C'est ce qui evite d'avoir a detruire une partie pour
lancer l'autre, et donc de perdre 8 minutes a chaque aller-retour entre p1 et p2.

---

## Q0 - Preliminaires

**Ce que l'evaluateur verifie**

- Le groupe evalue est present.
- Du travail a ete rendu (bons fichiers, bons dossiers, bons noms).
- Le depot Git est clone **sur la machine du groupe**.
- La **machine virtuelle de 42** est utilisee.

**A faire**

```bash
# Cloner dans un dossier VIDE, depuis le depot vogsphere du groupe
mkdir -p ~/soutenance && cd ~/soutenance
git clone <url-vogsphere> iot && cd iot
ls -la
```

Puis montrer qu'il n'y a pas d'alias piege :

```bash
alias
type make git kubectl
```

**Pieges**

- Cloner dans un dossier non vide fait echouer le point de la grille "Guidelines".
- Un `alias` charge dans le `.bashrc` peut etre lu comme une tentative de tricherie.
  Ouvrir un shell propre : `env -i bash --norc --noprofile` si l'evaluateur le demande.
- La virtualisation imbriquee (VT-x / AMD-V) doit etre exposee dans la VM 42,
  sinon p1 et p2 ne demarrent pas. `Tools/VM_commands.sh` le verifie.

---

## Q1 - General instructions

**Ce que l'evaluateur verifie**

- Le groupe l'aide a verifier chaque exigence.
- Les fichiers des trois parties sont bien dans `p1`, `p2` et `p3`.
  Un dossier `bonus` supplementaire est autorise.

**A faire**

```bash
find . -maxdepth 2 -not -path '*/.git*' | sort
```

Sortie attendue (structure du depot) :

```
./p1/Vagrantfile   ./p1/scripts   ./p1/confs   ./p1/README.md
./p2/Vagrantfile   ./p2/scripts   ./p2/confs   ./p2/README.md
./p3/scripts       ./p3/confs     ./p3/README.md
./bonus/scripts    ./bonus/confs  ./bonus/README.md
./Makefile ./README.md ./Docs ./Tools
```

**Preuve dans le repo** : la structure est conforme, y compris `p1/confs/`
(vide dans Git, il recoit le `node-token` publie par le serveur au provisioning,
cf. `p1/scripts/install_k3s_server.sh:59`).

**A expliquer si on demande** : `Docs/`, `Tools/` et le `Makefile` racine sont des
ajouts de confort, pas des fichiers imposes. La grille dit explicitement de
demander des explications sur les fichiers supplementaires : etre pret a
justifier `Tools/check_requirements.sh`, `Tools/cleanup.sh`, `Tools/VM_commands.sh`.

---

## Q2 - Configuration globale et explications

**Ce que l'evaluateur verifie** : le groupe sait expliquer simplement

1. le fonctionnement de base de K3s
2. le fonctionnement de base de Vagrant
3. le fonctionnement de base de K3d
4. ce qu'est l'integration continue et Argo CD

C'est la seule question purement orale. Elle ne coute rien a preparer et elle
peut faire echouer toute la soutenance ("If you have any doubt [...] the
evaluation stops now").

### 1. K3s

Distribution Kubernetes legere de Rancher, livree en **un seul binaire** d'environ
70 Mo. Elle retire d'un Kubernetes standard tout ce qui est optionnel :
etcd est remplace par SQLite par defaut, les drivers cloud et l'alpha sont retires.
Deux modes :

- `server` : execute le control plane (API server, scheduler, controller manager)
  et peut aussi executer des charges de travail. C'est `chillionS`.
- `agent` : execute uniquement kubelet et le runtime de conteneurs ; il rejoint le
  serveur avec une URL et un token. C'est `chillionSW`.

K3s embarque par defaut Traefik comme Ingress Controller, CoreDNS, un
load-balancer de service (`servicelb`) et flannel comme CNI.

### 2. Vagrant

Outil de HashiCorp qui **decrit une machine virtuelle dans un fichier**
(le `Vagrantfile`, en Ruby) et pilote un hyperviseur (ici VirtualBox) pour la
creer de facon reproductible. Les points cles :

- une *box* est une image de base (`bento/ubuntu-26.04`)
- `config.vm.network "private_network", ip: ...` cree une interface hote-invite
- les *provisioners* (ici `shell`) executent des scripts au premier `vagrant up`
- le dossier du `Vagrantfile` est monte automatiquement dans `/vagrant` sur l'invite
- `vagrant up`, `vagrant ssh`, `vagrant halt`, `vagrant destroy` sont le cycle de vie

### 3. K3d

Wrapper qui fait tourner **K3s dans des conteneurs Docker** au lieu de VMs.
Chaque node du cluster est un conteneur. Cela evite la virtualisation imbriquee,
demarre en quelques secondes et permet de publier des ports de l'hote vers le
cluster (`--port "8888:80@loadbalancer"`). K3d ajoute un conteneur
`serverlb` (Traefik/nginx en frontal) qui route le trafic entrant vers les nodes.

Difference a retenir : **K3s** = Kubernetes leger sur une machine reelle ou une VM ;
**K3d** = le meme K3s, mais chaque node est un conteneur Docker.

### 4. Integration continue et Argo CD

L'**integration continue** est la pratique consistant a integrer et valider
automatiquement chaque changement de code (build, tests, analyse) a chaque commit,
pour detecter les regressions immediatement plutot qu'a la fin.

**Argo CD** ne fait pas de CI : il fait du **CD declaratif, en mode GitOps**.
Le principe : l'etat desire du cluster est decrit dans un depot Git, et Argo CD
compare en permanence cet etat desire a l'etat reel du cluster.

- ressource `Application` (CRD) : elle declare *quel depot*, *quel chemin*,
  *quel cluster*, *quel namespace* (`p3/confs/application.yaml`)
- `syncPolicy.automated` : Argo CD applique le depot tout seul
  - `prune: true` : il supprime dans le cluster ce qui a disparu du depot
  - `selfHeal: true` : il annule toute modification faite a la main dans le cluster
- le polling par defaut est de **3 minutes** ; le bouton REFRESH force la detection

Phrase a retenir : *"Git est la source de verite ; on ne fait plus `kubectl apply`
a la main, on pousse un commit et Argo CD reconcilie."*

---

## Q3 - Partie 1 : Configuration

**Ce que l'evaluateur verifie**

| Point de la grille | Ou c'est prouve |
|---|---|
| Un `Vagrantfile` est present dans `p1` | `p1/Vagrantfile` |
| Le groupe sait expliquer son contenu | voir ci-dessous |
| Il y a **deux** machines virtuelles | `p1/Vagrantfile:22` et `:38` (deux blocs `config.vm.define`) |
| Derniere version stable de la distribution | `p1/Vagrantfile:5` -> `bento/ubuntu-26.04` (Ubuntu 26.04 LTS) |
| L'interface reseau primaire porte l'IP du sujet | `p1/Vagrantfile:9-10` -> `.110` et `.111` |
| Les noms contiennent un login du groupe, suivi de `S` et `SW` | `p1/Vagrantfile:7-8` -> `chillionS`, `chillionSW` |

**A faire**

```bash
cat p1/Vagrantfile
```

**A expliquer, ligne par ligne**

- `config.vm.box = "bento/ubuntu-26.04"` : l'image de base, derniere LTS Ubuntu.
- `vb.memory = 1024 / vb.cpus = 1` : les ressources minimales imposees par le sujet.
- `config.vm.define SERVER_NAME` : declare la premiere VM ; `server.vm.hostname`
  fixe le hostname **dans** l'invite, et `vb.name` fixe le nom **VirtualBox**
  (les deux sont mis a `chillionS`, donc `VBoxManage list vms` et `hostname`
  concordent - c'est exactement ce que l'evaluateur croise).
- `private_network, ip:` : cree une seconde interface (host-only) portant l'IP fixe.
- Les deux `provision "shell"` executent `scripts/install_k3s_server.sh` et
  `scripts/install_k3s_agent.sh`, en leur passant les IPs par variables
  d'environnement plutot qu'en dur.

**Le point qui merite d'etre mis en avant** : le token de jonction n'est pas ecrit
en dur dans le depot. Le serveur copie `/var/lib/rancher/k3s/server/node-token`
dans `/vagrant/confs/node-token` (`p1/scripts/install_k3s_server.sh:59-65`), et
l'agent le lit depuis ce dossier synchronise
(`p1/scripts/install_k3s_agent.sh:26-39`). Pas de secret commite, pas de cle SSH
partagee entre VMs.

**Piege** : *"If something does not work as expected, the evaluation stops here."*
Si `bento/ubuntu-26.04` n'est pas deja telecharge, `vagrant up` part chercher
~700 Mo sur le reseau. **Pre-telecharger la box la veille** (voir la section
Preparation).

---

## Q4 - Partie 1 : Usage

**Ce que l'evaluateur verifie**

- SSH via Vagrant sur les **deux** VMs
- L'interface configuree porte bien `192.168.56.110` et `192.168.56.111`
  (via `ip a`, en tenant compte des noms d'interfaces modernes type `enp0s8`)
- Les deux machines ont le hostname requis
- Les deux machines utilisent K3s
- `kubectl get nodes -o wide` sur le serveur montre les deux nodes dans le meme cluster
- Le groupe explique la sortie

**A faire**

```bash
make p1                     # ou : cd p1 && vagrant up
```

Puis, machine par machine :

```bash
# --- Serveur ---
cd p1 && vagrant ssh chillionS

hostname                    # -> chillionS
ip a                        # -> une interface (enp0s8) avec 192.168.56.110/24
sudo systemctl status k3s   # -> active (running)
k3s --version

kubectl get nodes -o wide   # KUBECONFIG deja exporte dans .bashrc
exit
```

```bash
# --- Worker ---
vagrant ssh chillionSW

hostname                          # -> chillionSW
ip a                              # -> 192.168.56.111/24
sudo systemctl status k3s-agent   # -> active (running)
exit
```

Verification complete en une commande :

```bash
make p1-verify        # lance p1/scripts/verify_cluster.sh sur chillionS
```

Ce script affiche les nodes, les pods systeme, l'interface detectee, deploie un
pod de test, le supprime, et conclut par `[PASS] Nodes: 2` et
`[PASS] Nodes Ready: 2/2`.

**Sortie attendue de `kubectl get nodes -o wide`**

```
NAME         STATUS   ROLES                  AGE   VERSION        INTERNAL-IP      ...
chillionS    Ready    control-plane,master   5m    v1.xx.x+k3s1   192.168.56.110   ...
chillionSW   Ready    <none>                 3m    v1.xx.x+k3s1   192.168.56.111   ...
```

**A expliquer (l'evaluateur le demande explicitement)**

- `ROLES: control-plane,master` sur `chillionS` : c'est lui qui heberge l'API server.
- `ROLES: <none>` sur `chillionSW` : c'est un agent, il ne fait qu'executer des pods.
- `INTERNAL-IP` : c'est la valeur passee par `--node-ip` dans les scripts
  d'installation. Sans ce flag, K3s prendrait l'IP NAT de Vagrant (`10.0.2.15`),
  identique sur les deux VMs, et le cluster serait casse. C'est le point technique
  a mettre en avant.
- `--flannel-iface "$IFACE"` : l'interface est **detectee a partir de l'IP**
  (`p1/scripts/install_k3s_server.sh:12`) et non ecrite en dur, donc le script
  reste valide que la box nomme son interface `eth1` ou `enp0s8`.

**Pieges**

- `kubectl get nodes` sur `chillionSW` echoue : normal, un agent n'a pas d'API
  server ni de kubeconfig. Le dire avant que l'evaluateur ne le teste.
- Si `vagrant ssh` demande un mot de passe, la cle Vagrant n'a pas ete injectee :
  detruire et relancer.

---

## Q5 - Partie 2 : Configuration

**Ce que l'evaluateur verifie**

| Point de la grille | Ou c'est prouve |
|---|---|
| Un `Vagrantfile` est present dans `p2` | `p2/Vagrantfile` |
| Il n'y a qu'**une seule** VM | `p2/Vagrantfile:14` (un seul `config.vm.define`) |
| Derniere version stable de la distribution | `p2/Vagrantfile:5` -> `bento/ubuntu-26.04` |
| L'interface primaire porte l'IP du sujet | `p2/Vagrantfile:8` et `:16` -> `192.168.56.110` |
| Le nom contient un login du groupe suivi de `S` | `p2/Vagrantfile:7` -> `llarreyS` (login d'un autre membre du groupe que p1) |
| Les fichiers supplementaires sont expliques | voir ci-dessous |

**A faire d'abord**

```bash
make p1-clean       # OBLIGATOIRE : meme nom de VM et meme IP que p2
make p2
```

La grille autorise explicitement d'eteindre les autres VMs pour des raisons de
place et de performance : le faire spontanement.

**Fichiers supplementaires a expliquer dans `p2/`**

- `confs/app1-deployment.yaml`, `app2-deployment.yaml`, `app3-deployment.yaml` :
  chacun contient un `Deployment` **et** une `ConfigMap` qui porte le `index.html`
  servi par nginx. C'est ce qui permet de distinguer visuellement les trois apps
  sans construire d'image custom.
- `confs/app1-service.yaml`, `app2-service.yaml`, `app3-service.yaml` :
  trois `Service` de type `ClusterIP` sur le port 80.
- `confs/ingress.yaml` : l'objet `Ingress` unique (`apps-ingress`) qui porte les
  trois regles de routage.
- `scripts/install_k3s.sh` : installe K3s en mode server avec `--node-ip` et
  `--flannel-iface` detectee.
- `scripts/setup_apps.sh` : applique les manifests depuis `/vagrant/confs` et
  attend le `rollout status` des trois deployments.
- `scripts/test_apps.sh` : les trois `curl` de verification.

---

## Q6 - Partie 2 : Usage

**Ce que l'evaluateur verifie**

- SSH via Vagrant sur la VM
- L'interface porte `192.168.56.110`
- Le hostname est correct
- La VM utilise K3s
- `kubectl get nodes -o wide` affiche le nom du controller et son IP interne
- `kubectl get all` affiche **3 applications** (deployments / pods / services),
  dont **app2 avec 3 replicas**
- Le groupe montre **comment son Ingress fonctionne** (la commande n'est
  volontairement pas donnee dans la grille)
- Les 3 applications repondent selon le **header HOST**

**A faire, dans la VM**

```bash
cd p2 && vagrant ssh llarreyS

hostname                    # -> llarreyS
ip a                        # -> 192.168.56.110/24
sudo systemctl status k3s

kubectl get nodes -o wide
kubectl get all
```

Sortie attendue de `kubectl get all` (namespace `default`, sans option) :

```
pod/app1-...                    1/1  Running
pod/app2-...  (x3)              1/1  Running
pod/app3-...                    1/1  Running

service/app1-service   ClusterIP  ...  80/TCP
service/app2-service   ClusterIP  ...  80/TCP
service/app3-service   ClusterIP  ...  80/TCP

deployment.apps/app1   1/1
deployment.apps/app2   3/3      <-- les 3 replicas du sujet
deployment.apps/app3   1/1
```

Les objets sont volontairement crees dans le namespace `default`
(`p2/scripts/setup_apps.sh:22-24`) : c'est ce que montre la sortie de reference
du sujet, et `kubectl get all` sans `-n` suffit alors a tout voir. Le dire, c'est
un choix, pas un oubli.

**La commande Ingress, celle que la grille ne donne pas**

```bash
kubectl get ingress
kubectl describe ingress apps-ingress
kubectl get pods -n kube-system | grep traefik
```

**A expliquer**

- L'`Ingress` n'est qu'un **objet de configuration** : il ne route rien tout seul.
- C'est **Traefik**, installe par defaut par K3s dans `kube-system`, qui lit cet
  objet et applique les regles. Il ecoute sur les ports 80 et 443 du node.
- `ingressClassName: traefik` (`p2/confs/ingress.yaml:10`) est la forme moderne.
  L'ancienne annotation `kubernetes.io/ingress.class` est depreciee et n'est plus
  prise en compte par Traefik v3 : c'est justement le piege classique de ce projet.
- Les trois regles (`p2/confs/ingress.yaml:13`, `:24`, `:35`) : une regle `host: app1.com`,
  une regle `host: app2.com`, et **une regle sans `host`** qui sert de defaut et
  renvoie vers `app3-service`.

**Le test HOST, depuis la machine hote**

```bash
curl -H "Host: app1.com" http://192.168.56.110    # -> Application 1
curl -H "Host: app2.com" http://192.168.56.110    # -> Application 2
curl http://192.168.56.110                        # -> Application 3 (defaut)

# ou en une fois :
make p2-test
```

Montrer aussi le load balancing sur app2 :

```bash
kubectl get pods -l app=app2 -o wide     # 3 pods, potentiellement sur le meme node
```

**Pieges**

- Faire les `curl` **depuis l'hote**, pas depuis la VM : c'est plus parlant et
  cela prouve que le reseau host-only fonctionne.
- Ne pas ajouter `app1.com` dans `/etc/hosts` : le header `Host` suffit, et cela
  demontre mieux la comprehension du routage par nom d'hote.

---

## Q7 - Partie 3 : Configuration

**Ce que l'evaluateur verifie**

- L'infrastructure demarre
- Les fichiers de configuration sont presents dans `p3` et sont expliques
- Il y a au moins 2 namespaces : `argocd` et `dev` (`kubectl get ns`)
- Il y a au moins 1 pod dans `dev` (`kubectl get pods -n dev`)
- Le groupe comprend **la difference entre un namespace et un pod**
- Les services requis tournent
- Argo CD est installe, configure, et **accessible depuis un navigateur** avec
  un login et un mot de passe fournis par le groupe
- Le **login d'un membre du groupe est dans le nom du depot GitHub**
- Une **image Docker** est utilisee dans le depot GitHub ; si elle est custom,
  le login doit etre dans le nom du depot Docker Hub, avec les **deux tags**
- Les fichiers supplementaires de `p3` sont expliques

**A faire**

```bash
make p2-clean       # liberer la RAM
make p3             # install + setup_cluster + deploy_app, ~5 min
```

Puis :

```bash
kubectl get ns                  # doit lister argocd ET dev
kubectl get pods -n dev         # au moins 1 pod wil-playground Running
kubectl get pods -n argocd      # argocd-server, repo-server, application-controller, redis, dex
kubectl get all -n dev
kubectl get application -n argocd -o wide
```

**Acces a l'interface Argo CD** (le point le plus souvent rate)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# puis dans le navigateur : https://localhost:8080
# login    : admin
# password :
kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d ; echo
```

Le service `argocd-server` reste volontairement en `ClusterIP`. Le passer en
`LoadBalancer` entrerait en conflit avec Traefik, qui occupe deja les ports 80 et
443 des nodes K3d. **Le dire avant qu'on ne le demande**, c'est un choix motive.
Le navigateur affichera un avertissement TLS (certificat auto-signe d'Argo CD) :
accepter l'exception.

**Difference namespace / pod - la reponse attendue**

- Un **pod** est la plus petite unite deployable de Kubernetes : un ou plusieurs
  conteneurs qui partagent le meme reseau (meme IP, meme `localhost`) et les memes
  volumes. C'est un objet *d'execution*.
- Un **namespace** est un cloisonnement **logique** a l'interieur d'un meme
  cluster : il regroupe des objets, permet des noms identiques dans deux
  namespaces differents, et sert de perimetre aux quotas et aux droits RBAC.
  C'est un objet *d'organisation*, il n'execute rien.
- Analogie : le namespace est le dossier, le pod est le processus.
- Ici : Argo CD tourne dans `argocd`, l'application deployee dans `dev`, ce qui
  separe l'outil de deploiement de la charge de travail deployee.

**Le depot GitHub**

- Depot : `https://github.com/BekxFR/trobert-iot-argocd-app.git`
  (`p3/confs/application.yaml:11`)
- Il contient `deployment.yaml`, `service.yaml`, `ingress.yaml`
  (structure documentee dans `p3/confs/GITHUB_SETUP.md`)
- **A verifier avant la soutenance** : le nom `trobert-iot-argocd-app` doit
  contenir le login d'un membre **du groupe inscrit sur l'intra**. Si `trobert`
  n'est pas un login du groupe alors que les VMs s'appellent `chillionS` et `llarreyS`,
  l'evaluateur peut refuser le point. C'est un renommage de 2 minutes cote GitHub,
  a faire maintenant plutot que pendant la defense (il faut aussi mettre a jour
  `p3/confs/application.yaml:9` et `p3/confs/GITHUB_SETUP.md`).

**L'image Docker**

- Image utilisee : `wil42/playground:v1` (`p3/confs/deployment.yaml:20`)
- C'est l'image **de Wil**, pas une image custom : la grille l'autorise
  explicitement ("The image can be Wil's or a custom one").
- Comme elle n'est pas custom, l'exigence "login dans le nom du depot Docker Hub"
  ne s'applique pas. En revanche il faut montrer que **les deux tags existent** :
  ouvrir `https://hub.docker.com/r/wil42/playground/tags` et montrer `v1` et `v2`.

**Fichiers supplementaires de `p3/` a expliquer**

- `confs/application.yaml` : la ressource `Application` d'Argo CD.
- `confs/deployment.yaml`, `service.yaml`, `ingress.yaml` : **copies locales de
  reference**. Attention : ce ne sont pas eux qu'Argo CD applique. Argo CD lit le
  depot GitHub. Les garder ici sert de documentation et de source pour initialiser
  le depot. C'est ecrit noir sur blanc en tete de `p3/confs/GITHUB_SETUP.md`.
- `confs/GITHUB_SETUP.md` : la procedure de creation du depot GitOps.
- `scripts/install.sh`, `setup_cluster.sh`, `deploy_app.sh`, `test.sh`, `cleanup.sh`.

**A expliquer sur `application.yaml`**

```yaml
source:
  repoURL: https://github.com/BekxFR/trobert-iot-argocd-app.git
  targetRevision: HEAD      # suit la branche par defaut
  path: .                   # les manifests sont a la racine du depot
destination:
  server: https://kubernetes.default.svc   # le cluster local
  namespace: dev
syncPolicy:
  automated:
    prune: true             # supprime du cluster ce qui disparait de Git
    selfHeal: true          # annule toute modification manuelle du cluster
```

`selfHeal: true` est le point a demontrer si on veut impressionner : supprimer le
deployment a la main (`kubectl delete deploy wil-playground -n dev`) et montrer
qu'Argo CD le recree tout seul.

---

## Q8 - Partie 3 : Usage

**Ce que l'evaluateur verifie**

- Navigation dans Argo CD, comprehension du fonctionnement
  (*"maybe their explanations are confused [...] the evaluation stops now"*)
- L'application **v1** est accessible depuis la machine
- **Docker Hub est utilise** (*"This part is important. In case of any doubt, the
  evaluation stops now."*)
- Le groupe fait **commit + push** d'une modification sur GitHub, ce qui declenche
  la mise a jour automatique
- Si la synchro n'a pas lieu, on la declenche **manuellement** dans Argo CD
- On verifie que l'application a bien ete synchronisee (v2)

**1. Montrer v1**

```bash
curl http://localhost:8888
# -> {"status":"ok", "message": "v1"}
```

Expliquer le chemin complet du paquet :
`localhost:8888` -> port publie par K3d sur le conteneur `serverlb`
(`p3/scripts/setup_cluster.sh:24`, `--port "8888:80@loadbalancer"`) -> port 80 du
node -> Traefik -> `Ingress wil-playground-ingress` -> `Service
wil-playground-service:8888` -> pod.

**2. Naviguer dans Argo CD**

Dans l'UI : cliquer sur l'application `wil-playground-app`, montrer l'arbre de
ressources (Application -> Deployment -> ReplicaSet -> Pod, plus Service et
Ingress), les badges `Synced` et `Healthy`, l'onglet `APP DETAILS` avec le
`repoURL`, et l'historique dans `HISTORY AND ROLLBACK`.

**3. Prouver Docker Hub**

```bash
kubectl get deployment wil-playground -n dev \
    -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# -> wil42/playground:v1
```

Ouvrir `https://hub.docker.com/r/wil42/playground/tags` et montrer `v1` et `v2`.
Expliquer que l'image sans prefixe de registre est tiree de Docker Hub par defaut.

**4. Le changement de version (le coeur de la question)**

```bash
git clone https://github.com/BekxFR/trobert-iot-argocd-app.git /tmp/argocd-app
cd /tmp/argocd-app
sed -i 's|wil42/playground:v1|wil42/playground:v2|' deployment.yaml
git diff                                    # montrer le diff a l'evaluateur
git add deployment.yaml
git commit -m "Update to v2"
git push origin main
```

**5. Synchronisation**

Le polling d'Argo CD est de 3 minutes. Deux options :

- attendre, en montrant l'application passer en `OutOfSync` puis `Synced`
- forcer : bouton **REFRESH** puis **SYNC** dans l'UI, ou en CLI :

```bash
argocd login localhost:8080 --username admin \
    --password "$(kubectl -n argocd get secret argocd-initial-admin-secret \
                  -o jsonpath='{.data.password}' | base64 -d)" --insecure
argocd app sync wil-playground-app
argocd app wait wil-playground-app --health
```

**6. Verifier**

```bash
curl http://localhost:8888
# -> {"status":"ok", "message": "v2"}

kubectl get deployment wil-playground -n dev \
    -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
# -> wil42/playground:v2

make p3-test        # recapitulatif complet
```

**Pieges**

- **Le depot GitHub fait foi.** Modifier `p3/confs/deployment.yaml` ne change
  strictement rien : Argo CD ne lit pas ce fichier. C'est l'erreur qui fait perdre
  la question. Toujours modifier dans le clone du depot GitHub.
- Prevoir les identifiants GitHub (token) **avant** la soutenance : un `git push`
  qui demande une authentification interactive au milieu de la demo fait perdre du temps.
- Remettre le depot en `v1` apres coup, sinon la prochaine soutenance demarre en v2 :
  ```bash
  sed -i 's|wil42/playground:v2|wil42/playground:v1|' deployment.yaml
  git commit -am "Back to v1" && git push
  ```

---

## Q9 - Bonus

> *"Evaluate the bonus part if, and only if, the mandatory part has been entirely
> and perfectly done, and the error management handles unexpected or wrong usage."*

Le bonus n'est meme pas regarde si une seule question obligatoire est ratee.
Deuxieme condition, souvent oubliee : **la gestion d'erreur**. Les scripts du
depot verifient systematiquement leurs prerequis avant d'agir
(`bonus/scripts/setup_cluster.sh:12` pour Docker,
`bonus/scripts/deploy_app.sh:14` pour le cluster,
`bonus/scripts/deploy_app.sh:19` pour Argo CD,
`bonus/scripts/configure_gitlab.sh:14` et `:20` pour GitLab). Le montrer si on
challenge ce point : lancer `./scripts/deploy_app.sh` sans cluster affiche un
`[FAIL]` explicite avec la commande a lancer, pas une stack trace.

### Bullet 1 - Les fichiers de configuration du dossier bonus

```bash
ls -R bonus
```

| Fichier | Role a expliquer |
|---|---|
| `confs/gitlab-values.yaml` | Values Helm minimales : desactive certmanager, nginx-ingress, prometheus, runner, registry, KAS, pages, LFS, artifacts ; force 1 replica par composant ; HTTP sans TLS. Sans ce fichier, le chart officiel deploie ~30 pods et sature la machine. |
| `confs/application.yaml` | La ressource `Application` d'Argo CD, identique a p3 **sauf le `repoURL`** qui pointe sur le GitLab interne. |
| `confs/deployment.yaml` | `wil42/playground:v1`, namespace `dev`, port 8888. Pousse dans GitLab par `configure_gitlab.sh`. |
| `confs/service.yaml` | `ClusterIP` sur 8888. |
| `confs/ingress.yaml` | `Ingress` Traefik vers le service. |
| `scripts/install.sh` | Ajoute Helm aux outils de p3 (+ `git` et `jq`). |
| `scripts/setup_cluster.sh` | Cluster `iot-bonus` + Argo CD + **3 namespaces** : `argocd`, `dev`, `gitlab`. |
| `scripts/deploy_gitlab.sh` | `helm upgrade --install gitlab gitlab/gitlab` avec les values ci-dessus. |
| `scripts/configure_gitlab.sh` | Cree un token, cree le projet `iot-app`, y pousse les manifests, et enregistre le depot dans Argo CD via un `Secret`. |
| `scripts/deploy_app.sh` | Applique `application.yaml` et attend la synchro. |
| `scripts/test.sh` / `cleanup.sh` | Verification complete / suppression du cluster. |

Le point technique a mettre en avant : le `Secret` de type repository cree en fin
de `configure_gitlab.sh:161-173`.

```yaml
labels:
  argocd.argoproj.io/secret-type: repository
stringData:
  url: http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/iot-app.git
  insecure: "true"
```

Ce label est ce qui fait qu'Argo CD reconnait le secret comme un depot enregistre.
L'URL est le **DNS interne Kubernetes** (`<service>.<namespace>.svc.cluster.local`) :
Argo CD parle a GitLab sans sortir du cluster, sans passer par l'hote. `insecure:
"true"` parce que la communication est en HTTP, TLS etant desactive dans les values.

### Bullet 2 - Creer un nouveau depot et y ajouter du code

C'est le seul point du bonus qui demande une action **improvisee pendant la
defense**. Il faut donc l'avoir repete.

```bash
# Port-forward et identifiants
kubectl port-forward svc/gitlab-webservice-default -n gitlab 30080:8181 &
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab \
    -o jsonpath='{.data.password}' | base64 -d ; echo
```

**Variante A (recommandee, API + git CLI)** - la procedure complete est dans
`bonus/README.md:139-167`. En resume :

```bash
TOOLBOX=$(kubectl get pods -n gitlab -l app=toolbox -o jsonpath='{.items[0].metadata.name}')
TOKEN=$(kubectl exec "$TOOLBOX" -n gitlab -c toolbox -- gitlab-rails runner "
puts User.find_by_username('root').personal_access_tokens.create!(
  scopes: [:api, :read_repository, :write_repository],
  name: 'demo-defense', expires_at: 30.days.from_now).token" | tail -1 | tr -d '\r\n')

curl -s -X POST "http://localhost:30080/api/v4/projects" \
    -H "PRIVATE-TOKEN: $TOKEN" -d "name=demo-defense&visibility=public" | jq '.web_url'

mkdir -p /tmp/demo-defense && cd /tmp/demo-defense && git init -b main
echo 'print("bonjour depuis GitLab local")' > hello.py
git config user.email "root@gitlab.local" && git config user.name "Administrator"
git add . && git commit -m "Ajout de hello.py"
git remote add origin "http://root:${TOKEN}@localhost:30080/root/demo-defense.git"
git push -u origin main

# Verification cote GitLab, c'est ce que la grille demande
curl -s "http://localhost:30080/api/v4/projects/root%2Fdemo-defense/repository/tree" \
    -H "PRIVATE-TOKEN: $TOKEN" | jq '.[].name'
```

**Variante B (interface web)** : `http://localhost:30080`, login `root`,
New project -> Create blank project -> `demo-defense`, puis `+` -> New file ->
Commit changes.

**Avertissement documente** (`bonus/README.md:179-190`) : le chart est configure
avec `global.hosts.domain: gitlab.local`. Certaines redirections de l'UI (apres
connexion notamment) pointent vers `http://gitlab.gitlab.local` plutot que vers
`localhost:30080`. Si le navigateur part sur une adresse injoignable, deux
solutions : rester sur la variante A, ou faire correspondre les deux noms :

```bash
echo "127.0.0.1 gitlab.gitlab.local" | sudo tee -a /etc/hosts
sudo kubectl port-forward svc/gitlab-webservice-default -n gitlab 80:8181
```

Nettoyage apres demo :

```bash
curl -s -X DELETE "http://localhost:30080/api/v4/projects/root%2Fdemo-defense" \
    -H "PRIVATE-TOKEN: $TOKEN"
```

### Bullet 3 - Tout ce qui marche en p3 marche encore, depuis GitLab

```bash
make bonus-test
```

Le script (`bonus/scripts/test.sh`) verifie dans l'ordre : cluster `iot-bonus`,
les 3 namespaces, pods GitLab Running, pods Argo CD Running, pod
`wil-playground` Running dans `dev`, reponse sur le port 8888, et surtout :

```bash
kubectl get application wil-playground-app -n argocd \
    -o jsonpath='{.spec.source.repoURL}{"\n"}'
# -> http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/iot-app.git
```

Les deux dernieres assertions du script sont exactement ce que la grille demande :
la source **contient** `gitlab` et **ne contient pas** `github`.

Montrer aussi les 3 namespaces cote a cote :

```bash
kubectl get ns          # argocd, dev, gitlab
kubectl get pods -n gitlab
```

### Bullet 4 - Synchronisation et changement de version sans erreur

```bash
kubectl port-forward svc/gitlab-webservice-default -n gitlab 30080:8181 &
GITLAB_PWD=$(kubectl get secret gitlab-gitlab-initial-root-password -n gitlab \
             -o jsonpath='{.data.password}' | base64 -d)

curl http://localhost:8888          # -> v1

git clone http://root:$GITLAB_PWD@localhost:30080/root/iot-app.git /tmp/iot-app
cd /tmp/iot-app
sed -i 's|wil42/playground:v1|wil42/playground:v2|' deployment.yaml
git add . && git commit -m "Upgrade to v2" && git push

# Attendre le polling (~3 min) ou forcer REFRESH + SYNC dans l'UI Argo CD
curl http://localhost:8888          # -> v2
```

C'est exactement le meme flux que la partie 3, sauf que le depot est interne au
cluster : rien ne sort vers Internet. C'est la phrase de conclusion du bonus.

**Pieges du bonus**

- GitLab met **15 a 20 minutes** a etre pret. Lancer `make bonus` bien avant la
  question 9, en prevenant l'evaluateur.
- Le port-forward vers GitLab doit tourner pendant toute la demo : le lancer avec
  `&` et verifier qu'il n'est pas mort (`jobs`).
- Le projet `iot-app` est cree en `visibility=public`, et le `Secret` Argo CD ne
  porte aucun identifiant : c'est cette visibilite publique qui permet le clone
  anonyme. Si le clone echoue cote Argo CD, verifier ce point en priorite
  (`kubectl describe application wil-playground-app -n argocd`).

---

## Flags et conclusion

| Flag | Quand il tombe |
|---|---|
| **Empty work** | Depot vide ou mauvais fichiers rendus |
| **Incomplete work** | Une partie obligatoire manquante ou non fonctionnelle |
| **Incomplete group** | Un membre du groupe absent a la defense |
| **Cheat** | Alias piege, depot qui n'appartient pas au groupe -> **-42** |
| **Crash** | Un script ou une commande plante pendant la demo |
| **Ok** | Tout passe |
| **Outstanding project** | Tout passe, bonus inclus, explications solides |

Rappel : les questions 3 a 8 se terminent toutes par *"If something does not work
as expected, the evaluation stops here"*. Il n'y a pas de rattrapage partiel :
chaque question est un point de passage bloquant.

---

## Preparation la veille

Le depot est complet, mais rien ne prouve qu'il a deja tourne de bout en bout sur
la machine de defense. Ces etapes doivent etre faites **avant** la soutenance, pas
pendant.

**1. Verifier les outils et la virtualisation**

```bash
make check-requirements     # vagrant, docker, kubectl, k3d
make check-versions
./Tools/VM_commands.sh      # verifie VT-x / AMD-V dans la VM 42
docker ps                   # doit fonctionner SANS sudo (sinon : newgrp docker)
```

Attention : `bonus/scripts/install.sh:60` et les scripts p1/p2 utilisent
`apt-get`. Ils supposent une machine Debian/Ubuntu. Sur une machine Fedora, ils
echouent.

**2. Pre-telecharger tout ce qui vient du reseau**

```bash
vagrant box add bento/ubuntu-26.04                   # ~700 Mo, valide aussi que la box existe
docker pull wil42/playground:v1
docker pull wil42/playground:v2
helm repo add gitlab https://charts.gitlab.io/ && helm repo update
```

**3. Faire un run complet a blanc, chronometre**

```bash
make p1 && make p1-verify && make p1-clean
make p2 && make p2-test    && make p2-clean
make p3 && make p3-test
# demo GitOps v1 -> v2 sur GitHub, puis retour a v1
make p3-clean
make bonus && make bonus-test
# demo creation de depot + demo GitOps v1 -> v2 sur GitLab
```

**4. Points a trancher avant la defense**

- Le nom du depot GitHub `trobert-iot-argocd-app` contient-il bien un login d'un
  membre du groupe inscrit sur l'intra ? Sinon, le renommer et mettre a jour
  `p3/confs/application.yaml:11`.
- L'UI web de GitLab est-elle atteignable, ou faut-il basculer sur la variante API ?
  (`bonus/README.md:179`)
- Le depot GitHub est-il bien revenu en `v1` ?
- Les identifiants GitHub (token de push) sont-ils configures sur la machine ?
- Y a-t-il assez de RAM ? GitLab reclame ~6 Go a lui seul.

**5. Si `/tmp` est petit ou en tmpfs**

```bash
make VM_STORAGE=$HOME/iot-vms p1
```

---

## Checklist finale

```
[ ] Depot clone dans un dossier vide, sur la machine du groupe, VM 42
[ ] find -maxdepth 2 montre p1/ p2/ p3/ bonus/ avec scripts/ et confs/
[ ] Je sais expliquer : K3s, Vagrant, K3d, CI + Argo CD
[ ] p1 : 2 VMs, bento/ubuntu-26.04, .110 et .111, chillionS et chillionSW
[ ] p1 : ssh sur les 2, ip a, hostname, systemctl k3s / k3s-agent
[ ] p1 : kubectl get nodes -o wide montre 2 nodes Ready, et je sais lire la sortie
[ ] Q3 et Q4 entierement terminees : make p2 detruira p1 sans retour
[ ] p2 : 1 seule VM, meme box, .110, llarreyS (login d'un autre membre du groupe)
[ ] p2 : kubectl get all montre 3 deployments dont app2 en 3/3
[ ] p2 : je sais montrer l'Ingress (get/describe ingress + traefik dans kube-system)
[ ] p2 : les 3 curl avec header Host donnent 3 reponses differentes
[ ] Q5 et Q6 entierement terminees avant de passer a p3
[ ] p3 : kubectl get ns montre argocd et dev
[ ] p3 : Argo CD accessible en navigateur, j'ai le mot de passe sous la main
[ ] p3 : je sais expliquer namespace vs pod
[ ] p3 : le nom du depot GitHub contient un login du groupe
[ ] p3 : Docker Hub montre wil42/playground avec les tags v1 ET v2
[ ] p3 : curl localhost:8888 -> v1
[ ] p3 : commit + push sur GitHub -> sync -> curl -> v2
[ ] p3 : depot remis en v1 apres la demo
[ ] Q7 et Q8 entierement terminees : make bonus supprimera le cluster iot-cluster
[ ] bonus : je sais expliquer chacun des 5 confs et des 7 scripts
[ ] bonus : creation d'un nouveau depot GitLab + push de code, repetee
[ ] bonus : kubectl get ns montre argocd, dev, gitlab
[ ] bonus : repoURL de l'Application contient gitlab et pas github
[ ] bonus : demo v1 -> v2 via le GitLab local, sans erreur
```
