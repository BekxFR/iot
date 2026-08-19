# Depannage VirtualBox / Vagrant

## Incident du 2026-08-07 : VM `<inaccessible>` apres reboot

### Symptome

`make p1` echoue immediatement :

```
There was an error while executing `VBoxManage`, a CLI used by Vagrant
for controlling VirtualBox. The command and stderr is shown below.

Command: ["showvminfo", "ad6e52e4-de1b-4c7f-8217-0d4e13a6f0b6"]

Stderr: VBoxManage: error: The object functionality is limited
VBoxManage: error: Details: code E_ACCESSDENIED (0x80070005), component MachineWrap, interface IMachine, callee nsISupports
VBoxManage: error: Context: "LockMachine(a->session, LockType_Shared)" at line 3328 of file VBoxManageInfo.cpp
```

### Cause

Le `defaultMachineFolder` de VirtualBox pointe sur `/tmp` :

```xml
<SystemProperties defaultMachineFolder="/tmp/chillion/VirtualBox VMs" .../>
<MachineEntry uuid="{ad6e52e4-...}" src="/tmp/chillion/VirtualBox VMs/chillionS/chillionS.vbox"/>
```

`/tmp` est vide au reboot. Consequence :

1. Les fichiers de la VM (`.vbox`, `.vdi`) disparaissent.
2. La VM reste **enregistree** dans `~/.config/VirtualBox/VirtualBox.xml` mais devient `<inaccessible>`.
3. Vagrant garde l'UUID perime dans `p1/.vagrant/machines/chillionS/virtualbox/id` et tente de verrouiller une machine qui n'existe plus -> `E_ACCESSDENIED`.

C'est donc reproductible **a chaque reboot**, ce n'est pas un bug ponctuel.

### Diagnostic

```bash
# Une VM listee comme "<inaccessible>" confirme le diagnostic
VBoxManage list vms

# Ou pointe le registre VirtualBox
grep -i 'MachineEntry\|defaultMachineFolder' ~/.config/VirtualBox/VirtualBox.xml

# Le dossier existe-t-il encore ?
ls -la "/tmp/chillion/VirtualBox VMs/"

# UUID que Vagrant croit encore valide
cat p1/.vagrant/machines/*/virtualbox/id
```

### Nettoyage applique

**1. Desenregistrer la VM fantome** (recuperer l'UUID via `VBoxManage list vms`) :

```bash
VBoxManage unregistervm <UUID> --delete
```

> `--delete` renvoie `The object is not ready / E_ACCESSDENIED` : c'est normal, il ne peut pas
> supprimer des fichiers deja absents. La VM est malgre tout desenregistree.
> Verifier avec `VBoxManage list vms` (doit renvoyer une liste vide).

**2. Purger l'etat Vagrant perime** :

```bash
rm -f p1/.vagrant/machines/chillionS/virtualbox/{id,index_uuid,action_set_name,disk_meta,creator_uid}
```

> Ne pas supprimer `vagrant_cwd`. Adapter le nom de machine (`chillionS`, `chillionSW`,
> `llarreyS` pour p2).

**3. Relancer** :

```bash
make p1
```

## Procedure rapide (copier-coller si ca recommence)

```bash
# Desenregistrer toutes les VMs inaccessibles
for uuid in $(VBoxManage list vms | grep '<inaccessible>' | grep -o '{[^}]*}'); do
    VBoxManage unregistervm "$uuid" --delete 2>/dev/null || VBoxManage unregistervm "$uuid"
done

# Purger l'etat Vagrant de p1 et p2 (garde vagrant_cwd)
find p1/.vagrant p2/.vagrant -path '*/virtualbox/*' -type f ! -name vagrant_cwd -delete 2>/dev/null

# Verifier que tout est propre
VBoxManage list vms      # doit etre vide
make p1
```

## Correctif de fond (optionnel)

Pour que le probleme ne revienne pas a chaque reboot, deplacer le dossier des VMs hors de `/tmp` :

```bash
mkdir -p ~/VirtualBox\ VMs
VBoxManage setproperty machinefolder ~/VirtualBox\ VMs
```

A ne faire que si l'espace disque de `$HOME` le permet (`df -h /home`) - le stockage dans `/tmp`
est parfois un choix delibere quand `$HOME` est sur NFS ou sous quota.

Pour revenir au comportement par defaut :

```bash
VBoxManage setproperty machinefolder default
```

## Autres erreurs frequentes

### `gurumeditation` au boot

```
The guest machine entered an invalid state while waiting for it to boot.
The machine is in the 'gurumeditation' state.
```

Crash CPU de l'invite. Cause typique ici : **virtualisation imbriquee** - cette machine est
elle-meme une VM VirtualBox (presence de `VBoxService`, modules `vboxguest`/`vboxsf`).

```bash
# Confirmer qu'on est dans une VM invitee
lsmod | grep -E 'vboxguest|vboxsf'
systemd-detect-virt
```

Pistes :

```bash
# 1. Autoriser le partage de VT-x avec l'hyperviseur parent
VBoxManage setproperty exclusiveHwVirt off

# 2. Cote hyperviseur PARENT (a executer sur la machine physique) :
#    activer la virtualisation imbriquee sur la VM qui heberge cet environnement
VBoxManage modifyvm <nom-vm-parente> --nested-hw-virt on

# 3. Nettoyer la VM crashee avant de reessayer
cd p1 && vagrant destroy -f && cd .. && make p1
```

Si la virtualisation imbriquee reste indisponible, p1/p2 (Vagrant + VirtualBox) ne peuvent pas
tourner dans cet environnement ; p3 et bonus (K3d/Docker) ne sont pas concernes.

**Resolution retenue (19/08/2026).** Sur les CPU Intel recents (12e/13e generation),
VirtualBox ne gere pas correctement cette double imbrication, quels que soient les
reglages ci-dessus. La VM hote a donc ete migree de VirtualBox vers QEMU/KVM, dont
le nested VMX est plus fiable. Le VirtualBox interne (p1/p2) est conserve.
Procedure complete : [MIGRATION_QEMU.md](MIGRATION_QEMU.md).

### `VBoxManage: error: Details: code NS_ERROR_FAILURE`, VM bloquee en `aborted`

```bash
cd p1 && vagrant destroy -f
VBoxManage list vms
make p1
```

### Modules noyau absents apres mise a jour du kernel

```bash
lsmod | grep vboxdrv          # doit lister vboxdrv, vboxnetadp, vboxnetflt
sudo /sbin/vboxconfig         # recompile les modules
```

### Interface hote-invite absente (192.168.56.x injoignable)

```bash
VBoxManage list hostonlyifs
cat /etc/vbox/networks.conf   # doit autoriser 192.168.56.0/21
```
