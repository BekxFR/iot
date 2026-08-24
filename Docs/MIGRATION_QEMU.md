# Migration de la VM hote : VirtualBox vers QEMU/KVM

## 1. Pourquoi cette migration

Le projet impose de travailler dans une VM. On avait donc trois couches :

```
L0  Fedora (machine physique 42)
 |
 +-- L1  VirtualBox : VM Debian "hote"
      |
      +-- L2  VirtualBox : VM Vagrant chillionS / chillionSW (p1, p2)
```

VirtualBox gere mal cette double imbrication sur les CPU Intel recents
(12e/13e generation, architecture hybride P-core/E-core). Resultat : les VM
Vagrant de p1 et p2 se figent au demarrage.

La correction consiste a remplacer **la couche externe** par QEMU/KVM, dont
la virtualisation imbriquee (nested VMX) est nettement plus fiable :

```
L0  Fedora + QEMU/KVM
 |
 +-- L1  VM Debian "hote"  (qcow2)
      |
      +-- L2  VirtualBox : VM Vagrant chillionS / chillionSW
```

Le VirtualBox **interne** (dans l'invite Debian) est conserve : les
Vagrantfile de p1 et p2 utilisent le provider `virtualbox`, et
`Docs/GRILLE_SOUTENANCE.md` s'appuie sur les noms de VM VirtualBox.

## 2. Etat de la migration

| Etape | Etat |
|---|---|
| Conversion `Debian.vdi` vers `Debian-VM.qcow2` | Fait |
| Agrandissement du disque virtuel (+60 Gio) | Fait cote QEMU |
| Premier demarrage de la VM | Fait, boot complet et fonctionnel |
| Import dans libvirt / virt-manager | Fait |
| Reconfiguration reseau dans l'invite | **A faire** (section 6) |
| Suppression des Guest Additions VirtualBox | **A faire** (section 6) |
| Extension de la partition dans l'invite | **A faire** (section 6) |
| Validation `make p1` sous QEMU | **A faire** (section 7) |

Aucune des etapes cote invite n'a encore ete faite. Une reconversion depuis
le `.vdi` ne perd donc rien : c'est la procedure de secours en cas de
probleme sur le `.qcow2` (voir section 4).

## 3. Ou se trouvent les fichiers

### Fichiers utilises par QEMU

| Chemin | Role |
|---|---|
| `/run/media/$USER/Extreme SSD/QEMU/Debian-VM.qcow2` | **Le disque de la VM.** Seul fichier d'etat : tout le systeme Debian est dedans. |
| `~/.config/libvirt/qemu/Debian-VM.xml` | Definition libvirt de la machine, **l'equivalent du fichier `.vbox`**. Dans le HOME, donc elle survit au changement de poste. |
| `Docs/Debian-VM.libvirt.xml` | La meme definition, versionnee dans le depot, pour pouvoir reimporter la VM. |
| `.../QEMU/Debian-VM-serial.log` | Journal de la console serie, cree uniquement avec `SERIAL_LOG=1`. |

QEMU seul n'a **pas de fichier de configuration** : toute la definition de
la machine (RAM, CPU, peripheriques, reseau) vit dans la ligne de commande,
donc dans le script `Docs/migrate-vbox-to-qemu.sh`. C'est la difference de
fond avec VirtualBox, qui stocke tout dans un `.vbox`.

L'import dans libvirt (section 5.1) restaure cet equivalent : la machine est
alors decrite en XML.

Caracteristiques du disque :

```
format         : qcow2
taille virtuelle : 160 Gio   (100 Gio d'origine + 60 Gio ajoutes)
taille reelle    : 62,3 Gio  (allocation a la demande)
```

### Fichiers d'origine VirtualBox (conserves)

```
/run/media/chillion/Extreme SSD/VirtualBox_VMs/Debian/Debian/
├── Debian.vbox      configuration VirtualBox
├── Debian.vdi       disque d'origine, 62,6 Gio  <-- INTACT
├── Debian.nvram
├── Logs/
└── Snapshots/       vide (aucun snapshot : la conversion etait sure)
```

La migration n'a **rien modifie** de ce dossier. Un retour arriere vers
VirtualBox reste possible a tout moment (section 9).

### Script

```
/goinfre/chillion/iot_42/Docs/migrate-vbox-to-qemu.sh
```

Il ne depend pas de son emplacement : tous les chemins qu'il manipule sont
absolus ou passes en argument. Il peut donc etre lance depuis n'importe ou.

## 4. Stockage du disque : ce qu'il faut savoir

### L'incident du 24/08/2026

Le disque avait d'abord ete place sur `/goinfre` (XFS local, rapide). Au
changement de poste, `/goinfre` a ete efface : disque perdu, et le depot a
du etre reclone. Le `.qcow2` a ete recopie sur le SSD externe, et il en est
ressorti **illisible** :

```
qemu-io read 510 2   ->  00 00      (signature MBR 55aa absente)
qemu-img check       ->  983007 clusters orphelins, code retour 2
```

Les 62 Gio de donnees etaient toujours physiquement presents mais plus
references : les metadonnees qcow2 qui les cartographient avaient disparu.
L'image a ete reconvertie depuis le `.vdi`, intact.

**A ne jamais faire sur une image dans cet etat : `qemu-img check -r leaks`
ou `-r all`.** La reparation consiste a liberer les clusters orphelins,
donc a effacer definitivement les donnees.

### Le compromis retenu

| | `/goinfre` (XFS) | SSD externe (exFAT) |
|---|---|---|
| Vitesse | Rapide, disque local | ~30 Mio/s, limite par l'USB |
| Survie au changement de poste | **Non, efface** | Oui |
| Journal | Oui | **Non** |
| Fichiers creux | Oui | Non |

Le SSD a ete retenu pour la durabilite. La contrepartie est reelle : exFAT
n'a pas de journal, donc une coupure ou un debranchement a chaud peut
detruire les metadonnees du `.qcow2`, comme ci-dessus.

### Precautions obligatoires

1. **Arreter la VM proprement** avant tout (section 5.6). Fermer la fenetre
   equivaut a couper le courant.
2. **Demonter le SSD proprement**, jamais en le debranchant :
   ```bash
   sync
   udisksctl unmount -b /dev/sda1
   ```
3. **Ne jamais supprimer `Debian.vdi`** : c'est le seul master fiable, et la
   reconversion ne coute que ~35 min.
4. **Verifier l'image apres chaque transport** du SSD :
   ```bash
   qemu-img check "/run/media/$USER/Extreme SSD/QEMU/Debian-VM.qcow2"
   ```
   Tout autre resultat que `No errors were found` signifie qu'il faut
   reconvertir depuis le `.vdi`.

### Alternative plus robuste

Si l'image se degrade a nouveau, convertir en **raw** plutot qu'en qcow2 :
un format sans metadonnees n'a pas de cartographie a perdre, une ecriture
partielle n'abime que la zone concernee.

```bash
qemu-img convert -p -O raw "<...>/Debian.vdi" "<...>/QEMU/Debian-VM.raw"
```

Cout : 160 Gio occupes en permanence au lieu de 62, exFAT ne gerant pas les
fichiers creux.

## 5. Lancer la VM

### 5.1 Interface graphique (virt-manager)

C'est l'equivalent le plus proche de l'interface VirtualBox : une liste de
VM, un double-clic pour demarrer, l'edition du materiel a la souris.

QEMU seul n'a ni interface de gestion ni registre de VM. La couche qui
manque s'appelle **libvirt** : elle stocke la definition de la machine en
XML (l'equivalent du `.vbox`) et virt-manager en est le client graphique.

```bash
virt-manager --connect qemu:///session
```

`Debian-VM` apparait dans la liste ; double-clic pour l'ouvrir, bouton Play
pour demarrer. Tout fonctionne **sans droits root** grace au mode session,
ou libvirt s'execute sous votre compte.

En ligne de commande :

```bash
virsh -c qemu:///session list --all
virsh -c qemu:///session start Debian-VM
virsh -c qemu:///session shutdown Debian-VM   # arret propre (ACPI)
virsh -c qemu:///session domstate Debian-VM
```

#### Importer ou reimporter la definition

Necessaire sur un poste ou la VM n'apparait pas encore, ou apres un
changement de chemin du disque :

```bash
# 1. verifier les deux valeurs specifiques a la machine dans le fichier :
#    le chemin du disque, et memory/vcpu selon la RAM du poste
virsh -c qemu:///session define Docs/Debian-VM.libvirt.xml
```

Pour changer uniquement le chemin du disque d'une VM deja definie :

```bash
virsh -c qemu:///session dumpxml Debian-VM > /tmp/vm.xml
sed -i "s|<source file=.*|<source file='/nouveau/chemin/Debian-VM.qcow2'/>|" /tmp/vm.xml
virsh -c qemu:///session define /tmp/vm.xml
```

#### Ne jamais lancer les deux methodes en meme temps

Le script et virt-manager sont deux definitions independantes du meme
fichier `.qcow2` : un demarrage simultane le corromprait. Le script refuse
de demarrer si la VM tourne deja sous libvirt.

| | Script | virt-manager |
|---|---|---|
| Affichage | Fenetre GTK directe | SPICE sur `127.0.0.1:5900` |
| Redirection de ports | SLIRP (`hostfwd`) | passt (`portForward`) |
| Dimensionnement | Calcule depuis la RAM de l'hote | Fixe dans le XML, a ajuster par poste |
| Definition | Ligne de commande du script | `~/.config/libvirt/qemu/Debian-VM.xml` |

### 5.2 Methode simple (script)

```bash
cd /goinfre/chillion/iot_42
./Docs/migrate-vbox-to-qemu.sh --run
```

Le script verifie les prerequis (KVM, nested, espace disque), puis demarre.

Variables surchargeables :

```bash
VM_RAM_MB=11264 ./Docs/migrate-vbox-to-qemu.sh --run   # pour le bonus (GitLab)
SERIAL_LOG=1    ./Docs/migrate-vbox-to-qemu.sh --run   # journaliser le boot
GL=on           ./Docs/migrate-vbox-to-qemu.sh --run   # OpenGL dans la fenetre
ACCEPT_EXFAT=1  ./Docs/migrate-vbox-to-qemu.sh --run   # ne pas redemander pour l'exFAT
OUT_DIR=/goinfre/$USER/QEMU ./Docs/migrate-vbox-to-qemu.sh --run   # tourner depuis le disque local
```

Sans surcharge, la RAM et le nombre de vCPU sont **calcules depuis l'hote**
(70% de la RAM, plafonnee a 16 Gio ; `nproc - 2` vCPU, plafonne a 8). Le
script affiche les valeurs retenues au demarrage.

### 5.3 Methode manuelle (commande QEMU complete)

C'est exactement ce que le script execute. Utile pour comprendre, adapter,
ou demarrer sans le script.

```bash
qemu-system-x86_64 \
  -name Debian-VM \
  -machine q35,accel=kvm \
  -cpu host \
  -smp 8,sockets=1,cores=8,threads=1 \
  -m 10240 \
  -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-pci,rng=rng0 \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -vga virtio \
  -display gtk,gl=off,zoom-to-fit=on \
  -device ahci,id=ahci \
  -drive file="/run/media/$USER/Extreme SSD/QEMU/Debian-VM.qcow2",format=qcow2,if=none,id=hd0,cache=writeback \
  -device ide-hd,drive=hd0,bus=ahci.0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8888-:8888,hostfwd=tcp::8443-:8443,hostfwd=tcp::8080-:8080 \
  -device virtio-net-pci,netdev=net0
```

### 5.4 Role de chaque option

| Option | Role |
|---|---|
| `-machine q35,accel=kvm` | Chipset moderne + acceleration materielle KVM. Sans `accel=kvm`, QEMU emule tout : inutilisable. |
| `-cpu host` | **Option critique.** Expose le jeu d'instructions reel du CPU a l'invite, y compris `vmx`. C'est ce qui permet a VirtualBox de fonctionner **dans** la VM. |
| `-smp 8,sockets=1,cores=8,threads=1` | 8 vCPU presentes comme 8 coeurs d'un seul socket. Topologie explicite pour eviter que l'invite voie 8 sockets. |
| `-m 10240` | 10 Gio sur un poste de 16 Go. Le script calcule cette valeur : **70% de la RAM de l'hote**, plafonnee a 16 Gio. Les postes de 42 n'ont pas tous la meme RAM, un chiffre en dur casse au changement de machine. Pour le bonus, GitLab reclame a lui seul ~6 Go : fermer les autres applications et monter a `VM_RAM_MB=11264`. |
| `-object rng-random` + `-device virtio-rng-pci` | Source d'entropie. k3s et GitLab generent beaucoup de certificats TLS au demarrage. |
| `-device qemu-xhci` + `-device usb-tablet` | Controleur USB et tablette. Donne un **pointeur absolu** : sans cela la souris se desynchronise dans la fenetre. |
| `-vga virtio` | Carte graphique virtio. |
| `-display gtk,gl=off,zoom-to-fit=on` | Fenetre GTK, redimensionnement automatique. `gl=on` accelere l'affichage mais echoue sur certaines configurations : laisser `off` par defaut. |
| `-device ahci` + `-device ide-hd` | Disque en SATA/AHCI. L'invite voit `/dev/sda`, **comme sous VirtualBox** : le `/etc/fstab` et GRUB restent valides sans modification. |
| `cache=writeback` | Bon compromis performance/securite. |
| `discard=unmap` | Absent ici : exFAT ne sait pas percer de trous. Sur un systeme de fichiers qui le supporte (XFS, ext4), l'ajouter permet au `fstrim` de l'invite de liberer reellement l'espace. |
| `-netdev user` | Reseau usermode (SLIRP), reseau interne `10.0.2.0/24`. Aucun privilege root requis. Pas de conflit avec le `192.168.56.0/24` de p1/p2, qui vit **a l'interieur** de l'invite. |
| `hostfwd=tcp::2222-:22` | Redirige le port 2222 de Fedora vers le port 22 de l'invite. Meme principe pour 8888 et 8443 (ingress Traefik de p3/bonus) et 8080 (port-forward Argo CD). |
| `-device virtio-net-pci` | Carte reseau paravirtualisee, bien plus rapide que l'emulation `e1000`. |

### 5.5 Variante : disque virtio (plus rapide)

Apres avoir verifie que l'initramfs de l'invite contient `virtio_blk` :

```bash
# dans l'invite
lsinitramfs /boot/initrd.img-$(uname -r) | grep virtio_blk
sudo update-initramfs -u    # si absent
```

Remplacer alors les trois lignes du disque par :

```bash
  -drive file="/run/media/$USER/Extreme SSD/QEMU/Debian-VM.qcow2",format=qcow2,if=none,id=hd0,cache=writeback \
  -device virtio-blk-pci,drive=hd0 \
```

Attention : l'invite verra desormais `/dev/vda` et non `/dev/sda`. Le
`fstab` de cette VM utilise des UUID, donc il reste valide, mais GRUB peut
demander une reinstallation. A ne tenter qu'apres avoir archive le `.qcow2`.

Le script gere cette variante via `DISK_BUS=virtio`.

### 5.6 Arreter la VM proprement

**Fermer la fenetre QEMU equivaut a couper l'alimentation.** L'ext4 rejouera
son journal au redemarrage, mais c'est a eviter. Trois methodes propres :

```bash
# 1. depuis l'invite
sudo poweroff

# 2. depuis le moniteur QEMU (fenetre GTK : menu View > compatmonitor0)
system_powerdown          # equivaut a un appui sur le bouton power (ACPI)

# 3. depuis Fedora
ssh <user>@localhost -p 2222 'sudo poweroff'

# 4. si la VM tourne sous libvirt / virt-manager
virsh -c qemu:///session shutdown Debian-VM    # ACPI, propre
virsh -c qemu:///session destroy  Debian-VM    # equivaut a couper le courant
```

Dans virt-manager, le bouton "Shut Down" envoie l'ACPI ; l'entree
"Force Off" du menu deroulant coupe brutalement.

**Le disque etant sur le SSD externe, l'arret de la VM ne suffit pas.**
Avant de debrancher le SSD :

```bash
sync
udisksctl unmount -b /dev/sda1
```

Un debranchement a chaud sur exFAT peut detruire l'image (section 4).

## 6. Ce qui reste a faire dans l'invite

A effectuer au prochain demarrage, dans cet ordre.

### 6.1 Reseau : l'interface a change de nom

QEMU presente une carte virtio sur un bus different de VirtualBox. Le nom
predictible de l'interface change donc (typiquement `enp0s3` devient
`enp1s0`).

```bash
ip -br link                       # relever le nouveau nom
sudo nano /etc/network/interfaces # remplacer l'ancien nom par le nouveau
sudo systemctl restart networking
ip -br addr                       # doit montrer une adresse en 10.0.2.x
ping -c2 1.1.1.1
```

Solution plus robuste, insensible au nom de l'interface :

```bash
# /etc/network/interfaces
allow-hotplug enp1s0
iface enp1s0 inet dhcp
```

### 6.2 Supprimer les Guest Additions VirtualBox

Elles fournissent un pilote graphique (VMSVGA) et des modules noyau
inadaptes a QEMU. Elles peuvent empecher X de demarrer avec `-vga virtio`.

```bash
sudo apt purge 'virtualbox-guest-*'
sudo apt autoremove --purge
sudo reboot
```

### 6.3 Recuperer les 60 Gio ajoutes

L'agrandissement a ete fait cote QEMU ; l'invite ne le voit pas encore.
Sans cette etape, il ne reste que ~37 Gio libres, ce qui est **insuffisant
pour le bonus** (images GitLab, k3d, box Vagrant, disques des VM imbriquees).

Disposition du disque de cette VM (verifiee) :

```
table de partitions : MBR (dos)
/dev/sda1           : amorcable, type 83 Linux, ext4, 100,5 Gio
                      UUID 2392a597-80e0-441a-8169-20c92bfcd91b
pas de LVM, pas de partition EFI, pas de partition swap dediee
```

La disposition est simple (une seule partition qui occupe tout le disque),
donc l'extension est directe :

```bash
df -h /                        # avant
sudo growpart /dev/sda 1       # etendre la partition
sudo resize2fs /dev/sda1       # etendre le systeme de fichiers ext4
df -h /                        # apres : environ 157 Gio
```

Si `growpart` est absent : `sudo apt install cloud-guest-utils`.

### 6.4 Verifier que la virtualisation imbriquee est arrivee

C'est le test qui valide toute la migration.

```bash
grep -Ec '(vmx|svm)' /proc/cpuinfo          # doit etre > 0
VBoxManage list hostinfo | grep -i 'hardware virt'
```

Si le compteur vaut 0, `-cpu host` n'a pas ete applique ou `nested` est
retombe a `N` sur la machine physique (voir section 8).

## 7. Validation

```bash
cd /goinfre/chillion/iot_42
make p1          # le vrai test : 2 VM Vagrant imbriquees
make p1-verify
make p2 && make p2-test
make p3 && make p3-test
make bonus       # le plus gourmand : GitLab
```

Depuis Fedora, les services de p3 et bonus sont joignables grace aux
redirections de ports :

| URL depuis Fedora | Service |
|---|---|
| `http://localhost:8888` | Ingress Traefik (app1.com, app2.com, app3) |
| `https://localhost:8443` | Ingress Traefik en TLS |
| `https://localhost:8080` | Argo CD (apres `kubectl port-forward`) |
| `ssh chillion@localhost -p 2222` | Shell dans la VM hote |

Pour `app1.com` et `app2.com`, ajouter dans le `/etc/hosts` de **Fedora** :

```
127.0.0.1 app1.com app2.com
```

## 8. Depannage

### La VM ne demarre pas : "Could not access KVM kernel module"

Une VM VirtualBox tourne encore sur Fedora et monopolise VT-x.

```bash
pgrep -a VirtualBoxVM VBoxHeadless    # les identifier
VBoxManage list runningvms            # les eteindre
```

### `grep -c vmx /proc/cpuinfo` renvoie 0 dans l'invite

La virtualisation imbriquee est desactivee sur la machine physique. Elle
n'est pas reglable sans root :

```bash
cat /sys/module/kvm_intel/parameters/nested     # doit afficher Y
```

Si le resultat est `N`, demander a l'administration :

```bash
echo "options kvm_intel nested=1" | sudo tee /etc/modprobe.d/kvm_intel-nested.conf
sudo modprobe -r kvm_intel && sudo modprobe kvm_intel
```

### VirtualBox echoue dans l'invite avec `VERR_VMX_...`

C'est la limite connue de l'empilement : VirtualBox comme hyperviseur
invite au-dessus de KVM est la combinaison la moins bien testee.

Solution de repli : basculer p1 et p2 sur le provider **libvirt**, ce qui
donne du KVM sur KVM, le chemin d'imbrication le mieux supporte sur Intel.

```bash
# dans l'invite
sudo apt install libvirt-daemon-system qemu-kvm
vagrant plugin install vagrant-libvirt
vagrant up --provider=libvirt
```

A ne faire qu'en dernier recours : il faudrait alors adapter les
`Vagrantfile` (les blocs `config.vm.provider "virtualbox"`) ainsi que
`Docs/GRILLE_SOUTENANCE.md` et `Docs/CONFORMITE_ANALYSE.md`, qui font
reference aux noms de VM VirtualBox.

### La fenetre ne s'ouvre pas

```bash
echo $DISPLAY $WAYLAND_DISPLAY        # doivent etre renseignes
```

En SSH sans affichage, remplacer `-display gtk,...` par `-display none` et
se connecter en SSH sur le port 2222.

### Un port de redirection est deja pris sur Fedora

```bash
ss -ltnp | grep -E ':(2222|8888|8443|8080)'
```

Le script ignore automatiquement les ports occupes et le signale. En manuel,
changer le port cote hote : `hostfwd=tcp::9999-:22`.

### Reduire la taille du fichier .qcow2

Apres suppression de donnees dans l'invite :

```bash
# dans l'invite (VM allumee)
sudo fstrim -av
# sur Fedora (VM eteinte)
qemu-img convert -p -O qcow2 Debian-VM.qcow2 Debian-VM-compact.qcow2
```

## 9. Retour arriere vers VirtualBox

Le `.vdi` d'origine n'a pas ete touche. Il suffit de redemarrer la VM
depuis VirtualBox :

```bash
VBoxManage startvm Debian
```

Attention : les modifications faites dans la VM QEMU depuis la conversion
ne s'y trouvent pas. Les deux disques ont diverge a partir du 19/08/2026.
Ne pas utiliser les deux en alternance.

## 10. References

- Script de migration : `Docs/migrate-vbox-to-qemu.sh`
- Definition libvirt de la VM : `Docs/Debian-VM.libvirt.xml`
- Contexte de l'incident VirtualBox : `Docs/DEPANNAGE_VIRTUALBOX.md`
- Contraintes d'evaluation : `Docs/CONSIGNES_POINTS_CLES.md`
- Besoins en ressources du bonus : `bonus/README.md`
