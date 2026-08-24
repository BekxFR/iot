#!/usr/bin/env bash
#
# create-vm-qemu.sh
# Cree et lance une VM QEMU/KVM dimensionnee pour le projet Inception-of-Things,
# a partir d'une image ISO. Aucun droit root requis.
#
# Le projet impose de travailler dans une VM, et p1/p2 lancent des VM Vagrant
# A L'INTERIEUR de celle-ci. Il faut donc de la virtualisation imbriquee, que
# VirtualBox gere mal sur les CPU Intel recents. QEMU/KVM la gere correctement.
#
# Usage :
#   ./create-vm-qemu.sh --iso debian-13-netinst.iso     # cree le disque et installe
#   ./create-vm-qemu.sh                                 # redemarre la VM installee
#   ./create-vm-qemu.sh --help
#
set -euo pipefail

### ---------- Valeurs par defaut ----------
VM_NAME="${VM_NAME:-iot-vm}"
OUT_DIR="${OUT_DIR:-$HOME/QEMU}"
DISK_GB="${DISK_GB:-100}"        # p1+p2 (2 VM imbriquees) + p3 (k3d) + bonus (images GitLab)
FIRMWARE="${FIRMWARE:-bios}"     # "bios" ou "uefi"
GL="${GL:-off}"                  # "on" = OpenGL dans la fenetre GTK
ISO=""
FORCE=0

# Redirections hote:invite. 22=SSH, 8888/8443=ingress Traefik (p2/p3/bonus),
# 8080=port-forward Argo CD, 30080=interface web GitLab (bonus).
FWD_PORTS=("2222:22" "8888:8888" "8443:8443" "8080:8080" "30080:30080")
### -----------------------------------------

log()  { printf '\033[1;34m[i]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<EOF
Usage : $0 [--iso FICHIER.iso] [options]

  --iso FICHIER    image d'installation (obligatoire au premier lancement)
  --name NOM       nom de la VM            (defaut: $VM_NAME)
  --dir CHEMIN     dossier du disque       (defaut: $OUT_DIR)
  --disk-gb N      taille du disque en Gio (defaut: $DISK_GB)
  --ram-mb N       RAM en Mo               (defaut: 70% de la RAM hote)
  --cpus N         vCPU                    (defaut: nproc-2, plafonne a 8)
  --uefi           demarrage UEFI au lieu de BIOS
  --force          recree le disque meme s'il existe (DESTRUCTIF)
  --help

Sans --iso et avec un disque existant, la VM redemarre depuis son disque.
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso)     ISO="${2:-}";      shift 2 ;;
    --name)    VM_NAME="${2:-}";  shift 2 ;;
    --dir)     OUT_DIR="${2:-}";  shift 2 ;;
    --disk-gb) DISK_GB="${2:-}";  shift 2 ;;
    --ram-mb)  VM_RAM_MB="${2:-}";shift 2 ;;
    --cpus)    VM_VCPUS="${2:-}"; shift 2 ;;
    --uefi)    FIRMWARE="uefi";   shift   ;;
    --force)   FORCE=1;           shift   ;;
    --help|-h) usage ;;
    *) err "Option inconnue : $1  (voir --help)" ;;
  esac
done

QCOW2_PATH="${OUT_DIR}/${VM_NAME}.qcow2"
OVMF_VARS_PATH="${OUT_DIR}/${VM_NAME}_VARS.fd"

# ---------- Dimensionnement adaptatif ----------
# Les postes n'ont pas tous la meme RAM : un chiffre en dur casse d'une machine
# a l'autre. 70% de la RAM hote, arrondi au Gio inferieur, plafonne a 16 Gio.
_host_ram_mb=$(( $(awk '/MemTotal/{print $2}' /proc/meminfo) / 1024 ))
_auto_ram=$(( _host_ram_mb * 70 / 100 / 1024 * 1024 ))
(( _auto_ram > 16384 )) && _auto_ram=16384
(( _auto_ram <  4096 )) && _auto_ram=4096
_auto_cpus=$(( $(nproc) - 2 ))
(( _auto_cpus > 8 )) && _auto_cpus=8
(( _auto_cpus < 1 )) && _auto_cpus=1
VM_RAM_MB="${VM_RAM_MB:-$_auto_ram}"
VM_VCPUS="${VM_VCPUS:-$_auto_cpus}"

# ================= 1. PREREQUIS =================
log "Diagnostic des prerequis..."
FAIL=0

command -v qemu-system-x86_64 >/dev/null || err "qemu-system-x86_64 absent (paquet qemu-system-x86)."
command -v qemu-img          >/dev/null || err "qemu-img absent (paquet qemu-img / qemu-utils)."

if grep -qm1 GenuineIntel /proc/cpuinfo; then KMOD=kvm_intel; else KMOD=kvm_amd; fi

if grep -Eqm1 '\b(vmx|svm)\b' /proc/cpuinfo; then
  ok "VT-x/AMD-V expose au systeme."
else
  warn "VT-x/AMD-V absent de /proc/cpuinfo : a activer dans le BIOS/UEFI du poste."
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
  warn "Nested (${KMOD}) = '${NESTED}' : desactive."
  warn "Sans cela, VirtualBox ne demarrera pas DANS la VM : p1 et p2 seront impossibles."
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

if ! printf 'quit\n' | timeout 20 qemu-system-x86_64 -machine q35,accel=kvm -m 128 \
     -display none -nodefaults -monitor stdio >/dev/null 2>&1; then
  err "KVM refuse de s'initialiser. Fermez toute VM VirtualBox en cours, puis relancez."
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
    warn "Le disque sera sur '$DEST_FS' ($OUT_DIR)."
    warn "Pas de journal : une coupure ou un debranchement a chaud peut rendre"
    warn "l'image illisible. Demonter TOUJOURS proprement (udisksctl unmount)."
    read -r -p "Continuer ? [y/N] " a; [[ "$a" =~ ^[yY]$ ]] || exit 1
    ;;
  *) ok "Destination sur '$DEST_FS' : adapte." ;;
esac

# ================= 3. DIMENSIONNEMENT =================
log "Hote : $(nproc) threads, ${_host_ram_mb} Mo de RAM."
(( VM_RAM_MB <= _host_ram_mb * 75 / 100 )) \
  || err "RAM demandee (${VM_RAM_MB} Mo) au-dela de 75% de celle de l'hote (${_host_ram_mb} Mo)."
(( VM_VCPUS <= $(nproc) - 2 )) || err "vCPU demandes (${VM_VCPUS}) : laisser au moins 2 threads a l'hote."
ok "Dimensionnement : ${VM_VCPUS} vCPU / ${VM_RAM_MB} Mo / ${DISK_GB} Gio."
if (( VM_RAM_MB < 12288 )); then
  warn "Sous 12 Go, la partie bonus sera juste : GitLab reclame ~6 Go a lui seul."
  warn "Fermer les autres applications, puis relancer avec --ram-mb $(( _host_ram_mb * 75 / 100 / 1024 * 1024 ))"
fi

# ================= 4. DISQUE =================
INSTALL_MODE=0
if [[ -f "$QCOW2_PATH" && "$FORCE" -eq 0 ]]; then
  ok "Disque existant reutilise : $QCOW2_PATH"
  [[ -n "$ISO" ]] && { INSTALL_MODE=1; warn "--iso fourni : demarrage sur l'ISO (le disque n'est PAS efface)."; }
else
  [[ -n "$ISO" ]] || err "Aucun disque a ${QCOW2_PATH} : fournir --iso pour installer le systeme."
  [[ -f "$ISO"  ]] || err "ISO introuvable : $ISO"
  if [[ -f "$QCOW2_PATH" ]]; then
    warn "--force : le disque existant va etre EFFACE ($QCOW2_PATH)"
    read -r -p "Confirmer la destruction ? [y/N] " a; [[ "$a" =~ ^[yY]$ ]] || exit 1
    rm -f "$QCOW2_PATH"
  fi
  FREE_MB=$(df -Pm "$OUT_DIR" | awk 'NR==2{print $4}')
  (( FREE_MB >= 20480 )) || warn "Seulement ${FREE_MB} Mo libres : le disque grossira a l'usage."
  log "Creation du disque (${DISK_GB} Gio, alloue a la demande)..."
  qemu-img create -f qcow2 "$QCOW2_PATH" "${DISK_GB}G" >/dev/null
  ok "Disque cree : $QCOW2_PATH"
  INSTALL_MODE=1
fi

if (( INSTALL_MODE )); then
  [[ -f "$ISO" ]] || err "ISO introuvable : $ISO"
  log "Mode INSTALLATION : demarrage sur $ISO"
fi

# ================= 5. COMMANDE QEMU =================
QEMU_ARGS=(
  -name "$VM_NAME"
  -machine q35,accel=kvm
  -cpu host                                  # expose vmx a l'invite : indispensable a p1/p2
  -smp "${VM_VCPUS},sockets=1,cores=${VM_VCPUS},threads=1"
  -m "$VM_RAM_MB"
  -object rng-random,filename=/dev/urandom,id=rng0   # k3s et GitLab generent beaucoup de TLS
  -device virtio-rng-pci,rng=rng0
  -device qemu-xhci,id=xhci
  -device usb-tablet,bus=xhci.0              # pointeur absolu, sinon la souris derive
  -vga virtio
  -display "gtk,gl=${GL},zoom-to-fit=on"
  -device ahci,id=ahci
  # Disque en SATA : l'invite voit /dev/sda, comme sous VirtualBox.
  -drive file="$QCOW2_PATH",format=qcow2,if=none,id=hd0,cache=writeback,discard=unmap
  -device ide-hd,drive=hd0,bus=ahci.0
)

if (( INSTALL_MODE )); then
  QEMU_ARGS+=(
    -drive file="$ISO",media=cdrom,if=none,id=cd0,readonly=on
    -device ide-cd,drive=cd0,bus=ahci.1
    -boot order=dc                           # CD d'abord, puis disque
  )
else
  QEMU_ARGS+=(-boot order=c)
fi

# Reseau usermode : aucun privilege root. Le 10.0.2.0/24 de l'invite n'entre pas
# en conflit avec le 192.168.56.0/24 utilise par p1 et p2 A L'INTERIEUR.
HOSTFWD=""
for p in "${FWD_PORTS[@]}"; do
  hp="${p%%:*}"
  if ss -Hltn "sport = :${hp}" 2>/dev/null | grep -q .; then
    warn "Port hote ${hp} deja occupe : redirection ignoree."
  else
    HOSTFWD+=",hostfwd=tcp::${hp}-:${p##*:}"
  fi
done
QEMU_ARGS+=(-netdev "user,id=net0${HOSTFWD}" -device virtio-net-pci,netdev=net0)

if [[ "$FIRMWARE" == "uefi" ]]; then
  OVMF_CODE=$(ls /usr/share/edk2/ovmf/OVMF_CODE.fd /usr/share/OVMF/OVMF_CODE.fd 2>/dev/null | head -1 || true)
  OVMF_VARS_SRC=$(ls /usr/share/edk2/ovmf/OVMF_VARS.fd /usr/share/OVMF/OVMF_VARS.fd 2>/dev/null | head -1 || true)
  [[ -n "$OVMF_CODE" && -n "$OVMF_VARS_SRC" ]] || err "--uefi mais OVMF introuvable (paquet edk2-ovmf)."
  # Copie INSCRIPTIBLE des variables : sinon le choix de demarrage ne persiste pas.
  [[ -f "$OVMF_VARS_PATH" ]] || cp "$OVMF_VARS_SRC" "$OVMF_VARS_PATH"
  QEMU_ARGS+=(
    -drive if=pflash,format=raw,unit=0,readonly=on,file="$OVMF_CODE"
    -drive if=pflash,format=raw,unit=1,file="$OVMF_VARS_PATH"
  )
fi

echo "----------------------------------------------------------------"
printf 'qemu-system-x86_64 %s\n' "${QEMU_ARGS[*]}"
echo "----------------------------------------------------------------"
if (( INSTALL_MODE )); then
  cat <<'EOF'

  PENDANT L'INSTALLATION
  - Choisir "Guided - use entire disk" : le disque est vide et dedie a la VM.
  - Cocher "SSH server" et "standard system utilities" dans la selection de
    logiciels. L'environnement de bureau est facultatif : le projet se pilote
    tres bien en SSH depuis l'hote (port 2222).
  - Noter le nom d'utilisateur choisi, il servira pour SSH.

  A LA FIN, retirer l'ISO : relancer ce script SANS --iso.

EOF
fi
log "Lancement de la VM..."
exec qemu-system-x86_64 "${QEMU_ARGS[@]}"

# ============ APRES L'INSTALLATION, DANS L'INVITE ============
#
# 1. Verifier que la virtualisation imbriquee est bien arrivee. C'est ce qui
#    conditionne p1 et p2 :
#      grep -Ec '(vmx|svm)' /proc/cpuinfo      # doit etre > 0
#
# 2. Outils de p1 et p2 (Vagrant pilote VirtualBox DANS la VM) :
#      sudo apt update && sudo apt install -y virtualbox vagrant
#      VBoxManage list hostinfo | grep -i 'hardware virt'
#
# 3. Outils de p3 puis du bonus : les scripts du depot s'en chargent.
#      ./p3/scripts/install.sh          # docker, kubectl, k3d
#      ./bonus/scripts/install.sh       # + helm, git, jq
#    Se reconnecter apres l'ajout au groupe docker, ou lancer 'newgrp docker'.
#
# 4. Depuis l'hote, une fois le systeme installe :
#      ssh <user>@localhost -p 2222
#
# 5. Ports joignables depuis l'hote pendant les demonstrations :
#      http://localhost:8888    ingress Traefik  (p2, p3, bonus)
#      https://localhost:8080   Argo CD          (apres kubectl port-forward)
#      http://localhost:30080   GitLab           (apres kubectl port-forward)
