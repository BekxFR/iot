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
| Verification d'integrite (`qemu-img check`) | Fait, aucune erreur |
| Agrandissement du disque virtuel (+60 Gio) | Fait cote QEMU |
| Premier demarrage de la VM | Fait, boot complet et fonctionnel |
| Reconfiguration reseau dans l'invite | **A faire** (section 6) |
| Suppression des Guest Additions VirtualBox | **A faire** (section 6) |
| Extension de la partition dans l'invite | **A faire** (section 6) |
| Validation `make p1` sous QEMU | **A faire** (section 7) |

## 3. Ou se trouvent les fichiers

### Fichiers utilises par QEMU

| Chemin | Role |
|---|---|
| `/goinfre/$USER/QEMU/Debian-VM.qcow2` | **Le disque de la VM.** C'est le seul fichier d'etat : tout le systeme Debian est dedans. |
| `/goinfre/$USER/QEMU/Debian-VM_VARS.fd` | Variables UEFI. **N'existe pas ici** : cette VM demarre en BIOS. |
| `/goinfre/$USER/QEMU/Debian-VM-serial.log` | Journal de la console serie, cree uniquement avec `SERIAL_LOG=1`. |

Contrairement a VirtualBox, **il n'y a pas de fichier de configuration**
(pas d'equivalent du `.vbox`). Toute la definition de la machine (RAM, CPU,
peripheriques, reseau) vit dans la ligne de commande QEMU, donc dans le
script `Docs/migrate-vbox-to-qemu.sh`.

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

## 4. AVERTISSEMENT : /goinfre n'est pas une sauvegarde

`/goinfre` est un espace **local a la machine** et **effacable** par
l'administration de 42. Consequences :

- Sur une autre station, le `.qcow2` **ne sera pas la**. Il faut le recopier
  ou relancer la conversion depuis le `.vdi` du SSD.
- Le `.vdi` sur le SSD externe est la seule copie durable. **Ne pas le
  supprimer.**
- Pour archiver l'etat courant de la VM QEMU sur le SSD :
  ```bash
  qemu-img convert -p -O qcow2 -c \
    /goinfre/$USER/QEMU/Debian-VM.qcow2 \
    "/run/media/$USER/Extreme SSD/QEMU/Debian-VM-backup.qcow2"
  ```
  (`-c` compresse ; comptez du temps, le SSD externe plafonne vers 40 Mio/s.)

Le `.qcow2` n'a pas ete place sur le SSD externe parce que celui-ci est en
**exFAT** : pas de fichiers creux, pas de journal, et un debranchement a
chaud corrompt l'image. `/goinfre` est en XFS local, bien plus rapide et sur
pour un disque de VM en cours d'utilisation.

## 5. Lancer la VM

### 5.1 Methode simple (script)

```bash
cd /goinfre/chillion/iot_42
./Docs/migrate-vbox-to-qemu.sh --run
```

Le script verifie les prerequis (KVM, nested, espace disque), puis demarre.

Variables surchargeables :

```bash
VM_RAM_MB=20480 VM_VCPUS=12 ./Docs/migrate-vbox-to-qemu.sh --run   # plus de ressources
SERIAL_LOG=1              ./Docs/migrate-vbox-to-qemu.sh --run   # journaliser le boot
GL=on                     ./Docs/migrate-vbox-to-qemu.sh --run   # OpenGL dans la fenetre
```

### 5.2 Methode manuelle (commande QEMU complete)

C'est exactement ce que le script execute. Utile pour comprendre, adapter,
ou demarrer sans le script.

```bash
qemu-system-x86_64 \
  -name Debian-VM \
  -machine q35,accel=kvm \
  -cpu host \
  -smp 8,sockets=1,cores=8,threads=1 \
  -m 16384 \
  -object rng-random,filename=/dev/urandom,id=rng0 \
  -device virtio-rng-pci,rng=rng0 \
  -device qemu-xhci,id=xhci \
  -device usb-tablet,bus=xhci.0 \
  -vga virtio \
  -display gtk,gl=off,zoom-to-fit=on \
  -device ahci,id=ahci \
  -drive file=/goinfre/$USER/QEMU/Debian-VM.qcow2,format=qcow2,if=none,id=hd0,cache=writeback,discard=unmap \
  -device ide-hd,drive=hd0,bus=ahci.0 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8888-:8888,hostfwd=tcp::8443-:8443,hostfwd=tcp::8080-:8080 \
  -device virtio-net-pci,netdev=net0
```

### 5.3 Role de chaque option

| Option | Role |
|---|---|
| `-machine q35,accel=kvm` | Chipset moderne + acceleration materielle KVM. Sans `accel=kvm`, QEMU emule tout : inutilisable. |
| `-cpu host` | **Option critique.** Expose le jeu d'instructions reel du CPU a l'invite, y compris `vmx`. C'est ce qui permet a VirtualBox de fonctionner **dans** la VM. |
| `-smp 8,sockets=1,cores=8,threads=1` | 8 vCPU presentes comme 8 coeurs d'un seul socket. Topologie explicite pour eviter que l'invite voie 8 sockets. |
| `-m 16384` | 16 Gio. Dimensionne pour le bonus : GitLab reclame a lui seul ~6 Go, auxquels s'ajoutent Debian, Docker, k3d et Argo CD. |
| `-object rng-random` + `-device virtio-rng-pci` | Source d'entropie. k3s et GitLab generent beaucoup de certificats TLS au demarrage. |
| `-device qemu-xhci` + `-device usb-tablet` | Controleur USB et tablette. Donne un **pointeur absolu** : sans cela la souris se desynchronise dans la fenetre. |
| `-vga virtio` | Carte graphique virtio. |
| `-display gtk,gl=off,zoom-to-fit=on` | Fenetre GTK, redimensionnement automatique. `gl=on` accelere l'affichage mais echoue sur certaines configurations : laisser `off` par defaut. |
| `-device ahci` + `-device ide-hd` | Disque en SATA/AHCI. L'invite voit `/dev/sda`, **comme sous VirtualBox** : le `/etc/fstab` et GRUB restent valides sans modification. |
| `cache=writeback` | Bon compromis performance/securite. |
| `discard=unmap` | Le `fstrim` de l'invite libere reellement l'espace dans le `.qcow2`. |
| `-netdev user` | Reseau usermode (SLIRP), reseau interne `10.0.2.0/24`. Aucun privilege root requis. Pas de conflit avec le `192.168.56.0/24` de p1/p2, qui vit **a l'interieur** de l'invite. |
| `hostfwd=tcp::2222-:22` | Redirige le port 2222 de Fedora vers le port 22 de l'invite. Meme principe pour 8888 et 8443 (ingress Traefik de p3/bonus) et 8080 (port-forward Argo CD). |
| `-device virtio-net-pci` | Carte reseau paravirtualisee, bien plus rapide que l'emulation `e1000`. |

### 5.4 Variante : disque virtio (plus rapide)

Apres avoir verifie que l'initramfs de l'invite contient `virtio_blk` :

```bash
# dans l'invite
lsinitramfs /boot/initrd.img-$(uname -r) | grep virtio_blk
sudo update-initramfs -u    # si absent
```

Remplacer alors les trois lignes du disque par :

```bash
  -drive file=/goinfre/$USER/QEMU/Debian-VM.qcow2,format=qcow2,if=none,id=hd0,cache=writeback,discard=unmap \
  -device virtio-blk-pci,drive=hd0 \
```

Attention : l'invite verra desormais `/dev/vda` et non `/dev/sda`. Le
`fstab` de cette VM utilise des UUID, donc il reste valide, mais GRUB peut
demander une reinstallation. A ne tenter qu'apres avoir archive le `.qcow2`.

Le script gere cette variante via `DISK_BUS=virtio`.

### 5.5 Arreter la VM proprement

**Fermer la fenetre QEMU equivaut a couper l'alimentation.** L'ext4 rejouera
son journal au redemarrage, mais c'est a eviter. Trois methodes propres :

```bash
# 1. depuis l'invite
sudo poweroff

# 2. depuis le moniteur QEMU (fenetre GTK : menu View > compatmonitor0)
system_powerdown          # equivaut a un appui sur le bouton power (ACPI)

# 3. depuis Fedora
ssh <user>@localhost -p 2222 'sudo poweroff'
```

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
- Contexte de l'incident VirtualBox : `Docs/DEPANNAGE_VIRTUALBOX.md`
- Contraintes d'evaluation : `Docs/CONSIGNES_POINTS_CLES.md`
- Besoins en ressources du bonus : `bonus/README.md`
