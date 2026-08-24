#!/usr/bin/env bash
#
# migrate-vbox-to-qemu.sh
# Migration + lancement de la VM hote Debian (VirtualBox) sous QEMU/KVM, sans root.
#
# Pourquoi : VirtualBox gere mal l'imbrication VBox-dans-VBox sur les CPU recents
# (Intel 12e/13e gen hybrides). En passant la couche EXTERNE sur QEMU/KVM, le
# VirtualBox interne recoit un VMX imbrique propre expose par KVM.
#
# Prerequis non modifiables sans root (le script les VERIFIE) :
#   1. nested=1 sur kvm_intel/kvm_amd
#   2. acces en lecture/ecriture a /dev/kvm
#
# Usage :
#   ./migrate-vbox-to-qemu.sh /chemin/vers/disque.vdi   # convertit puis demarre
#   ./migrate-vbox-to-qemu.sh --run                     # redemarre le qcow2 existant
#
# Variables surchargeables :
#   VM_RAM_MB VM_VCPUS OUT_DIR VM_NAME FIRMWARE DISK_GROW_GB NET_BACKEND GL
#
set -euo pipefail

### ---------- Parametres ----------
VM_NAME="${VM_NAME:-Debian-VM}"
# Dimensionnement ADAPTATIF : les postes de 42 n'ont pas tous la meme RAM
# (31 Go sur l'un, 15 Go sur l'autre). Un chiffre en dur casse au changement
# de machine. Par defaut : 70% de la RAM hote, arrondi au Gio inferieur,
# plafonne a 16 Gio ; et nproc-2 vCPU, plafonne a 8.
_host_ram_mb=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 ))
_auto_ram=$(( _host_ram_mb * 70 / 100 / 1024 * 1024 ))
(( _auto_ram > 16384 )) && _auto_ram=16384
(( _auto_ram <  4096 )) && _auto_ram=4096
_auto_cpus=$(( $(nproc) - 2 ))
(( _auto_cpus > 8 )) && _auto_cpus=8
(( _auto_cpus < 1 )) && _auto_cpus=1

VM_RAM_MB="${VM_RAM_MB:-$_auto_ram}"     # surchargeable : VM_RAM_MB=11264 pour le bonus
VM_VCPUS="${VM_VCPUS:-$_auto_cpus}"
OUT_DIR="${OUT_DIR:-/run/media/$USER/Extreme SSD/QEMU}"  # survit au changement de machine
                                         # voir ACCEPT_EXFAT et la section 4 de MIGRATION_QEMU.md
FIRMWARE="${FIRMWARE:-bios}"             # "bios" ou "uefi" (doit correspondre a la VM VBox)
DISK_GROW_GB="${DISK_GROW_GB:-60}"       # agrandissement du disque virtuel (0 = aucun)
NET_BACKEND="${NET_BACKEND:-user}"       # "user" (SLIRP, sur) ou "passt" (plus rapide)
GL="${GL:-off}"                          # "on" = OpenGL dans la fenetre GTK
DISK_BUS="${DISK_BUS:-ahci}"             # "ahci" (=> /dev/sda, sur) ou "virtio" (=> /dev/vda, rapide)

# Redirections hote:invite. 22 = SSH, 8888/8443 = ingress k3d p3/bonus,
# 8080 = port-forward Argo CD, 3000/5000 = anciennes regles NAT VirtualBox.
FWD_PORTS=("2222:22" "8888:8888" "8443:8443" "8080:8080" "3000:3000" "5000:5000")
### --------------------------------

QCOW2_PATH="${OUT_DIR}/${VM_NAME}.qcow2"
OVMF_VARS_PATH="${OUT_DIR}/${VM_NAME}_VARS.fd"

log()  { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

RUN_ONLY=0
CONVERT_ONLY=0
SRC_DISK=""
case "${1:-}" in
  --run|--run-only) RUN_ONLY=1 ;;
  --convert-only)   CONVERT_ONLY=1; SRC_DISK="${2:-}" ;;
  "") err "Usage : $0 /chemin/vers/disque.vdi | $0 --convert-only <vdi> | $0 --run" ;;
  *)  SRC_DISK="$1" ;;
esac
# Accepte un dossier : on y cherche l'unique .vdi
if [[ -d "${SRC_DISK:-}" ]]; then
  mapfile -t _vdis < <(find "$SRC_DISK" -maxdepth 1 -name '*.vdi')
  (( ${#_vdis[@]} == 1 )) || { printf '[x] %s\n' "Attendu 1 seul .vdi dans $SRC_DISK, trouve ${#_vdis[@]}." >&2; exit 1; }
  SRC_DISK="${_vdis[0]}"
fi

# ================= 1. DIAGNOSTIC (lecture seule) =================
log "Diagnostic des prerequis..."
FAIL=0

command -v qemu-system-x86_64 >/dev/null || err "qemu-system-x86_64 absent (paquet qemu-system-x86)."
command -v qemu-img          >/dev/null || err "qemu-img absent (paquet qemu-img / qemu-utils)."

# Vendeur CPU fiable (ne pas deduire du flag vmx : absent si VT-x coupe dans le BIOS)
if grep -qm1 'GenuineIntel' /proc/cpuinfo; then KMOD=kvm_intel; else KMOD=kvm_amd; fi

if grep -Eqm1 '\b(vmx|svm)\b' /proc/cpuinfo; then
  ok "VT-x/AMD-V expose au systeme."
else
  warn "VT-x/AMD-V absent de /proc/cpuinfo : a activer dans le BIOS/UEFI."
  FAIL=1
fi

if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  ok "/dev/kvm accessible."
else
  warn "/dev/kvm inaccessible. Groupes actuels : $(id -nG)"
  FAIL=1
fi

NESTED=$(cat "/sys/module/${KMOD}/parameters/nested" 2>/dev/null || echo "?")
if [[ "$NESTED" =~ ^(Y|1)$ ]]; then
  ok "Virtualisation imbriquee (${KMOD}) : active."
else
  warn "Nested (${KMOD}) = '${NESTED}' : desactive. Sans cela, VirtualBox DANS la VM ne demarrera pas."
  FAIL=1
fi

if [[ "$FAIL" -ne 0 ]]; then
  cat <<EOF

============ A FAIRE PAR L'ADMINISTRATEUR (une seule fois) ============
echo "options ${KMOD} nested=1" | sudo tee /etc/modprobe.d/${KMOD}-nested.conf
sudo modprobe -r ${KMOD} && sudo modprobe ${KMOD}     # ou reboot
cat /sys/module/${KMOD}/parameters/nested              # doit afficher Y

sudo usermod -aG kvm $USER                             # puis se reconnecter
=======================================================================
EOF
  exit 1
fi

# Verification reelle que KVM s'initialise (vboxdrv peut monopoliser VT-x)
if ! printf 'quit\n' | timeout 20 qemu-system-x86_64 -machine q35,accel=kvm -m 128 \
     -display none -nodefaults -monitor stdio >/dev/null 2>&1; then
  err "KVM refuse de s'initialiser. Fermez toutes les VM VirtualBox en cours puis relancez."
fi
ok "KVM operationnel."

if pgrep -x VirtualBoxVM >/dev/null 2>&1 || pgrep -x VBoxHeadless >/dev/null 2>&1; then
  warn "Une VM VirtualBox tourne encore : elle se dispute VT-x avec QEMU. Eteignez-la."
fi

# ================= 2. DESTINATION =================
mkdir -p "$OUT_DIR"
DEST_FS=$(findmnt -no FSTYPE -T "$OUT_DIR")
case "$DEST_FS" in
  exfat|vfat|ntfs|ntfs3|fuseblk)
    # Choix assume : le SSD externe survit au changement de machine, contrairement
    # a /goinfre qui est efface. Contrepartie : pas de journal, donc une coupure
    # ou un debranchement a chaud peut detruire les metadonnees qcow2.
    # Une image a deja ete perdue ainsi le 24/08/2026.
    warn "OUT_DIR est sur '$DEST_FS' ($OUT_DIR)."
    warn "Pas de journal : demonter TOUJOURS proprement (udisksctl unmount -b /dev/sda1)"
    warn "et arreter la VM avant, sinon l'image peut devenir illisible."
    EXFAT_DEST=1
    if [[ "${ACCEPT_EXFAT:-0}" != "1" ]]; then
      read -r -p "Continuer quand meme ? [y/N] " a; [[ "$a" =~ ^[yY]$ ]] || exit 1
    fi
    ;;
  *) ok "Destination sur '$DEST_FS' : adapte."; EXFAT_DEST=0 ;;
esac

# ================= 3. DIMENSIONNEMENT =================
HOST_RAM_MB=$(( $(grep -m1 MemTotal /proc/meminfo | awk '{print $2}') / 1024 ))
HOST_CPUS=$(nproc)
log "Hote : ${HOST_CPUS} threads, ${HOST_RAM_MB} Mo de RAM."
(( VM_RAM_MB <= HOST_RAM_MB * 75 / 100 )) \
  || err "VM_RAM_MB=${VM_RAM_MB} depasse 75% de la RAM hote (${HOST_RAM_MB} Mo)."
(( VM_VCPUS <= HOST_CPUS - 2 )) \
  || err "VM_VCPUS=${VM_VCPUS} laisse moins de 2 threads a l'hote."
if (( VM_RAM_MB < 12288 )); then
  warn "VM_RAM_MB=${VM_RAM_MB} : le bonus (GitLab ~6 Go + k3d + Argo CD) sera juste."
  warn "Pour le bonus, fermer les autres applications puis : VM_RAM_MB=$(( _host_ram_mb * 75 / 100 / 1024 * 1024 ))"
fi
ok "Dimensionnement : ${VM_VCPUS} vCPU / ${VM_RAM_MB} Mo."

# ================= 4. CONVERSION =================
if [[ "$RUN_ONLY" -eq 0 ]]; then
  [[ -f "$SRC_DISK" ]] || err "Fichier introuvable : $SRC_DISK"
  SRC_DIR=$(dirname "$SRC_DISK")

  # Garde-fous : un disque de base avec des snapshots enfants est PERIME.
  if compgen -G "${SRC_DIR}/Snapshots/*.vdi" >/dev/null; then
    err "Des snapshots existent dans ${SRC_DIR}/Snapshots/.
     '$SRC_DISK' est le disque de BASE, pas l'etat courant : conversion interdite.
     Fusionnez d'abord : VBoxManage snapshot <VM> delete <nom>   (pour chaque snapshot)."
  fi
  if compgen -G "${SRC_DIR}/Snapshots/*.sav" >/dev/null; then
    err "Un etat sauvegarde (.sav) existe : la VM n'est pas eteinte proprement.
     Faites : VBoxManage discardstate <VM>   puis un arret propre depuis l'invite."
  fi
  for vb in "${SRC_DIR}"/*.vbox; do
    [[ -f "$vb" ]] || continue
    grep -q 'location="Snapshots/' "$vb" && err "Chaine differentielle detectee dans $(basename "$vb"). Fusionnez les snapshots."
    grep -q 'aborted="true"' "$vb" && warn "$(basename "$vb") : derniere extinction anormale. Prevoyez un fsck dans l'invite."
  done

  [[ -f "$QCOW2_PATH" ]] && err "Existe deja : $QCOW2_PATH
     Relancez avec --run pour le demarrer, ou supprimez-le, ou changez VM_NAME."

  SRC_BYTES=$(qemu-img info --output=json "$SRC_DISK" | grep -m1 '"actual-size"' | tr -dc '0-9')
  NEED_MB=$(( SRC_BYTES / 1048576 + DISK_GROW_GB * 1024 + 5120 ))
  FREE_MB=$(df -Pm "$OUT_DIR" | awk 'NR==2{print $4}')
  (( FREE_MB >= NEED_MB )) || err "Espace insuffisant sur $OUT_DIR : ${FREE_MB} Mo libres, ${NEED_MB} Mo requis."

  log "Conversion vers qcow2 (source $(( SRC_BYTES / 1073741824 )) Gio, peut prendre du temps)..."
  qemu-img convert -p -O qcow2 "$SRC_DISK" "$QCOW2_PATH"
  ok "Disque converti : $QCOW2_PATH"

  if (( DISK_GROW_GB > 0 )); then
    qemu-img resize "$QCOW2_PATH" "+${DISK_GROW_GB}G"
    ok "Disque virtuel agrandi de +${DISK_GROW_GB} Gio."
    cat <<'EOF'
    Note : l'espace ajoute n'est pas encore visible dans l'invite. Apres le
    premier demarrage, agrandir la partition puis le systeme de fichiers :
      sudo growpart /dev/sda N            # N = numero de la partition
      # LVM : sudo pvresize /dev/sdaN && sudo lvextend -l +100%FREE /dev/VG/LV
      sudo resize2fs /dev/...             # ou xfs_growfs /
EOF
  fi
fi

if (( CONVERT_ONLY )); then
  ok "Conversion terminee. Demarrage : $0 --run"
  exit 0
fi

[[ -f "$QCOW2_PATH" ]] || err "Aucun qcow2 a demarrer : $QCOW2_PATH"

# ---- Garde-fou : jamais deux machines sur le meme disque ----
# La VM est aussi definie dans libvirt (virt-manager). Demarrer les deux en
# meme temps sur le meme qcow2 le corromprait.
if command -v virsh >/dev/null 2>&1; then
  LIBVIRT_STATE=$(virsh -c qemu:///session domstate "$VM_NAME" 2>/dev/null | tr -d ' \n' || true)
  if [[ "$LIBVIRT_STATE" == "running" || "$LIBVIRT_STATE" == "paused" ]]; then
    err "'$VM_NAME' tourne deja sous libvirt/virt-manager (etat: $LIBVIRT_STATE).
     Utiliser virt-manager, ou l'arreter : virsh -c qemu:///session shutdown $VM_NAME"
  fi
fi
if pgrep -af "qemu-system-x86_64.*${QCOW2_PATH}" >/dev/null 2>&1; then
  err "Un processus QEMU utilise deja $QCOW2_PATH.
     Le demarrer deux fois corromprait le disque."
fi

# ================= 5. CONSTRUCTION DE LA COMMANDE QEMU =================
QEMU_ARGS=(
  -name "$VM_NAME"
  -machine q35,accel=kvm
  -cpu host                                    # expose vmx a l'invite : indispensable au nested
  -smp "${VM_VCPUS},sockets=1,cores=${VM_VCPUS},threads=1"
  -m "$VM_RAM_MB"
  -object rng-random,filename=/dev/urandom,id=rng0   # entropie : k3s/GitLab generent beaucoup de TLS
  -device virtio-rng-pci,rng=rng0
  -device qemu-xhci,id=xhci
  -device usb-tablet,bus=xhci.0                # pointeur absolu : souris utilisable en GUI
  -vga virtio
  -display "gtk,gl=${GL},zoom-to-fit=on"
)

# SERIAL_LOG=1 : journalise la console serie de l'invite dans un fichier.
# Utile pour savoir POURQUOI un boot echoue quand la fenetre se ferme.
# Reste vide si l'invite n'a pas de console serie activee dans GRUB
# (ajouter console=ttyS0,115200 a GRUB_CMDLINE_LINUX pour l'activer).
if [[ "${SERIAL_LOG:-0}" == "1" ]]; then
  QEMU_ARGS+=(-serial "file:${OUT_DIR}/${VM_NAME}-serial.log")
  log "Console serie journalisee dans ${OUT_DIR}/${VM_NAME}-serial.log"
fi

# --- Disque ---
if [[ "$DISK_BUS" == "virtio" ]]; then
  QEMU_ARGS+=(
    -drive file="$QCOW2_PATH",format=qcow2,if=none,id=hd0,cache=writeback,discard=unmap
    -device virtio-blk-pci,drive=hd0
  )
  warn "DISK_BUS=virtio : l'invite verra /dev/vda. A n'utiliser qu'apres avoir verifie"
  warn "que l'initramfs contient virtio_blk (lsinitramfs / update-initramfs -u)."
else
  # discard=unmap est inutile sur exFAT (pas de punch-hole) : on l'omet.
  DRIVE_OPTS="file=$QCOW2_PATH,format=qcow2,if=none,id=hd0,cache=writeback"
  (( EXFAT_DEST )) || DRIVE_OPTS+=",discard=unmap"
  QEMU_ARGS+=(
    -device ahci,id=ahci
    -drive "$DRIVE_OPTS"
    -device ide-hd,drive=hd0,bus=ahci.0        # /dev/sda comme sous VirtualBox : fstab par UUID inchange
  )
fi

# --- Reseau ---
# Le reseau usermode (10.0.2.0/24) n'entre pas en conflit avec le 192.168.56.0/24
# utilise par p1/p2 a l'interieur de l'invite.
PORTS_ACTIFS=()
for p in "${FWD_PORTS[@]}"; do
  hp="${p%%:*}"
  if ss -Hltn "sport = :${hp}" 2>/dev/null | grep -q .; then
    warn "Port hote ${hp} deja occupe : redirection ignoree."
  else
    PORTS_ACTIFS+=("$p")
  fi
done

if [[ "$NET_BACKEND" == "passt" ]] && command -v passt >/dev/null; then
  TCP=$(IFS=,; echo "${PORTS_ACTIFS[*]}")           # 2222:22,8888:8888,...
  TCP="${TCP//,/,,}"                                 # virgules echappees pour QEMU
  QEMU_ARGS+=(-netdev "passt,id=net0,tcp-ports=${TCP}" -device virtio-net-pci,netdev=net0)
  log "Reseau : passt (plus rapide que SLIRP)."
else
  HOSTFWD=""
  for p in "${PORTS_ACTIFS[@]}"; do HOSTFWD+=",hostfwd=tcp::${p%%:*}-:${p##*:}"; done
  QEMU_ARGS+=(-netdev "user,id=net0${HOSTFWD}" -device virtio-net-pci,netdev=net0)
  log "Reseau : SLIRP usermode + virtio-net."
fi

# --- Firmware ---
if [[ "$FIRMWARE" == "uefi" ]]; then
  OVMF_CODE=$(ls /usr/share/edk2/ovmf/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd 2>/dev/null | head -1 || true)
  OVMF_VARS_SRC=$(ls /usr/share/edk2/ovmf/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS.fd 2>/dev/null | head -1 || true)
  [[ -n "$OVMF_CODE" && -n "$OVMF_VARS_SRC" ]] || err "FIRMWARE=uefi mais OVMF introuvable (paquet edk2-ovmf)."
  # Les variables UEFI doivent etre une copie INSCRIPTIBLE, sinon le boot ne persiste pas.
  [[ -f "$OVMF_VARS_PATH" ]] || cp "$OVMF_VARS_SRC" "$OVMF_VARS_PATH"
  QEMU_ARGS+=(
    -drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF_CODE"
    -drive if=pflash,format=raw,unit=1,file="$OVMF_VARS_PATH"
  )
fi

log "Lancement de la VM..."
printf '%s\n' "----------------------------------------------------------------"
printf 'qemu-system-x86_64 %s\n' "${QEMU_ARGS[*]}"
printf '%s\n' "----------------------------------------------------------------"
exec qemu-system-x86_64 "${QEMU_ARGS[@]}"

# ============ APRES LE 1er DEMARRAGE (dans l'invite Debian) ============
# 1. Purger les Guest Additions VirtualBox (elles cassent X avec virtio-vga) :
#      sudo apt purge 'virtualbox-guest-*' && sudo reboot
# 2. Verifier le nested :  grep -Ec '(vmx|svm)' /proc/cpuinfo   (doit etre > 0)
# 3. Interface reseau renommee (enp1s0 au lieu de enp0s3) :
#      corriger /etc/network/interfaces, ou utiliser 'allow-hotplug'/DHCP generique.
# 4. Verifier VirtualBox interne :  VBoxManage list hostinfo | grep -i 'hardware virt'
# 5. Agrandir le disque si DISK_GROW_GB > 0 (voir growpart/resize2fs ci-dessus).
# 6. SSH depuis Fedora :  ssh <user>@localhost -p 2222
