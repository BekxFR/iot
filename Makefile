.PHONY: all p1 p1-up p1-down p1-clean p1-status p1-ssh p1-verify \
        p2 p2-up p2-down p2-clean p2-status p2-ssh p2-test \
        p3 p3-install p3-setup p3-deploy p3-up p3-down p3-clean p3-test p3-status check-docker \
        bonus bonus-install bonus-setup bonus-gitlab bonus-gitlab-deploy bonus-gitlab-configure \
        bonus-deploy bonus-test bonus-clean bonus-status bonus-down \
        clean fclean cleanup-files status help check check-requirements logs-clean check-versions \
        vbox-prune

# Variables de configuration
VAGRANT_P1_DIR = p1
VAGRANT_P2_DIR = p2
P3_DIR = p3
BONUS_DIR = bonus

# Stockage des box Vagrant et des disques VirtualBox.
# Surchargeable si /tmp est un tmpfs (RAM) ou trop petit :
#   make VM_STORAGE=/goinfre/$(USER) p1
VM_STORAGE ?= /tmp/chillion
export VAGRANT_HOME = $(VM_STORAGE)/.vagrant.d
VBOX_VM_DIR = $(VM_STORAGE)/VirtualBox VMs

# Couleurs pour l'affichage
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

# Affichage d'aide par défaut
help:
	@echo "$(BLUE)===== Inception-of-Things (IoT) Project =====$(NC)"
	@echo "$(GREEN)Commandes disponibles:$(NC)"
	@echo ""
	@echo "$(YELLOW)Partie 1 - K3s et Vagrant:$(NC)"
	@echo "  make p1         - Lance la partie 1 (K3s + Vagrant)"
	@echo "  make p1-up      - Démarre les VMs de la partie 1"
	@echo "  make p1-down    - Arrête les VMs de la partie 1"
	@echo "  make p1-clean   - Détruit les VMs de la partie 1"
	@echo "  make p1-status  - Affiche le statut des VMs"
	@echo "  make p1-ssh     - SSH vers le server (chillionS)"
	@echo "  make p1-verify  - Vérification complète du cluster"
	@echo ""
	@echo "$(YELLOW)Partie 2 - K3s et Applications:$(NC)"
	@echo "  make p2         - Lance la partie 2"
	@echo "  make p2-up      - Démarre la VM de la partie 2"
	@echo "  make p2-down    - Arrête la VM de la partie 2"
	@echo "  make p2-clean   - Détruit la VM de la partie 2"
	@echo "  make p2-status  - Affiche le statut de la VM"
	@echo "  make p2-ssh     - SSH vers le server (llarreyS)"
	@echo "  make p2-test    - Teste les applications web"
	@echo ""
	@echo "$(YELLOW)Partie 3 - K3d et Argo CD:$(NC)"
	@echo "  make p3           - Lance la partie 3 complète"
	@echo "  make p3-install   - Installe les outils (Docker, K3d, Argo CD)"
	@echo "  make p3-setup     - Configure le cluster K3d"
	@echo "  make p3-deploy    - Déploie l'application"
	@echo "  make p3-up        - Démarre le cluster K3d"
	@echo "  make p3-down      - Arrête le cluster K3d"
	@echo "  make p3-clean     - Supprime le cluster K3d"
	@echo "  make p3-test      - Teste l'application et GitOps"
	@echo ""
	@echo "$(YELLOW)Bonus - GitLab local sur K3d:$(NC)"
	@echo "  make bonus          - Lance le bonus complet"
	@echo "  make bonus-install  - Installe Helm + outils"
	@echo "  make bonus-setup    - Configure le cluster K3d + Argo CD"
	@echo "  make bonus-gitlab   - Déploie et configure GitLab"
	@echo "  make bonus-deploy   - Déploie l'application via Argo CD"
	@echo "  make bonus-test     - Teste le bonus complet"
	@echo "  make bonus-clean    - Supprime le cluster K3d du bonus"
	@echo "  make bonus-status   - Affiche le statut du bonus"
	@echo ""
	@echo "$(YELLOW)Commandes globales:$(NC)"
	@echo "  make all          - Lance toutes les parties"
	@echo "  make clean        - Nettoie toutes les parties + fichiers temporaires"
	@echo "  make fclean       - Force le nettoyage complet"
	@echo "  make cleanup-files - Nettoie uniquement les fichiers temporaires"
	@echo "  make status       - Affiche le statut de toutes les parties"
	@echo ""
	@echo "$(YELLOW)Exclusivité entre les parties (automatique, rien n'est détruit):$(NC)"
	@echo "  p1 (chillionS) et p2 (llarreyS) partagent l'IP 192.168.56.110 :"
	@echo "    make p1 arrête p2, et make p2 arrête p1 (vagrant halt)."
	@echo "  p3 et bonus publient les mêmes ports 8888/8443/6550 :"
	@echo "    make p3 arrête iot-bonus, et make bonus arrête iot-cluster (k3d cluster stop)."
	@echo "  make bonus arrête aussi les VM Vagrant : GitLab réclame ~6 Go de RAM."
	@echo ""
	@echo "$(YELLOW)Documentation et aide:$(NC)"
	@echo "  make help         - Affiche cette aide"
	@echo "  make check        - Vérifie la conformité aux consignes"
	@echo "  Consignes détaillées: Docs/CONSIGNES_POINTS_CLES.md"
	@echo "  Documentation par partie: p1/README.md, p2/README.md, p3/README.md"

# ==================== UTILITAIRES VIRTUALBOX ====================
# Desenregistre les VMs devenues inaccessibles : le .vbox a disparu mais l'UUID
# reste dans le registre VirtualBox. Cas typique, $(VM_STORAGE) sous /tmp purge
# au reboot. VBoxManage repond alors E_ACCESSDENIED sur cet UUID, ce qui fait
# echouer vagrant destroy : p1-clean/p2-clean deviennent impossibles a passer.
vbox-prune:
	@command -v VBoxManage >/dev/null 2>&1 || exit 0; \
	VBoxManage list vms 2>/dev/null \
	  | sed -n 's/^"<inaccessible>" {\(.*\)}$$/\1/p' \
	  | while read -r uuid; do \
	      echo "$(YELLOW)VM inaccessible detectee ($$uuid) : desenregistrement$(NC)"; \
	      VBoxManage unregistervm "$$uuid" >/dev/null 2>&1 \
	        || echo "$(RED)Echec du desenregistrement de $$uuid$(NC)"; \
	    done; \
	exit 0

# ==================== PARTIE 1 ====================
p1: p1-up
	@echo "$(GREEN)Partie 1 lancée avec succès$(NC)"

# p1 et p2 partagent l'IP 192.168.56.110 imposée par le sujet : une seule peut tourner à la fois.
p1-up: p2-down
	@echo "$(BLUE)Démarrage de la Partie 1 (K3s + Vagrant)...$(NC)"
	@VBoxManage setproperty machinefolder "$(VBOX_VM_DIR)"
	cd $(VAGRANT_P1_DIR) && vagrant up
	@echo "$(GREEN)VMs de la partie 1 démarrées$(NC)"
	@echo "$(YELLOW)Vérification du cluster...$(NC)"
	cd $(VAGRANT_P1_DIR) && vagrant ssh chillionS -c "sudo kubectl get nodes -o wide" || true

p1-verify:
	@echo "$(BLUE)Vérification complète de la Partie 1...$(NC)"
	cd $(VAGRANT_P1_DIR) && vagrant ssh chillionS -c "/vagrant/scripts/verify_cluster.sh"

p1-down:
	@echo "$(YELLOW)Arrêt des VMs de la partie 1...$(NC)"
	cd $(VAGRANT_P1_DIR) && vagrant halt
	@echo "$(GREEN)VMs de la partie 1 arrêtées$(NC)"

p1-clean: vbox-prune
	@echo "$(RED)Nettoyage de la partie 1...$(NC)"
	cd $(VAGRANT_P1_DIR) && vagrant destroy -f
	@echo "$(GREEN)Partie 1 nettoyée$(NC)"

p1-status:
	@echo "$(BLUE)Statut de la Partie 1:$(NC)"
	cd $(VAGRANT_P1_DIR) && vagrant status

p1-ssh:
	@echo "$(BLUE)Connexion SSH au serveur (chillionS)...$(NC)"
	cd $(VAGRANT_P1_DIR) && vagrant ssh chillionS

# ==================== PARTIE 2 ====================
p2: p2-up
	@echo "$(GREEN)Partie 2 lancée avec succès$(NC)"

p2-up: p1-down
	@echo "$(BLUE)Démarrage de la Partie 2 (K3s + Applications)...$(NC)"
	@VBoxManage setproperty machinefolder "$(VBOX_VM_DIR)"
	cd $(VAGRANT_P2_DIR) && vagrant up
	@echo "$(GREEN)VM de la partie 2 démarrée$(NC)"
	@echo "$(YELLOW)Vérification des applications...$(NC)"
	cd $(VAGRANT_P2_DIR) && vagrant ssh llarreyS -c "sudo kubectl get pods -A" || true

p2-down:
	@echo "$(YELLOW)Arrêt de la VM de la partie 2...$(NC)"
	cd $(VAGRANT_P2_DIR) && vagrant halt
	@echo "$(GREEN)VM de la partie 2 arrêtée$(NC)"

p2-clean: vbox-prune
	@echo "$(RED)Nettoyage de la partie 2...$(NC)"
	cd $(VAGRANT_P2_DIR) && vagrant destroy -f
	@echo "$(GREEN)Partie 2 nettoyée$(NC)"

p2-status:
	@echo "$(BLUE)Statut de la Partie 2:$(NC)"
	cd $(VAGRANT_P2_DIR) && vagrant status

p2-test:
	@echo "$(BLUE)Test des applications web...$(NC)"
	@echo "$(YELLOW)Test app1.com:$(NC)"
	curl -H "Host: app1.com" http://192.168.56.110 || echo "$(RED)app1 non accessible$(NC)"
	@echo "$(YELLOW)Test app2.com:$(NC)"
	curl -H "Host: app2.com" http://192.168.56.110 || echo "$(RED)app2 non accessible$(NC)"
	@echo "$(YELLOW)Test app par défaut:$(NC)"
	curl http://192.168.56.110 || echo "$(RED)app3 non accessible$(NC)"

p2-ssh:
	@echo "$(BLUE)Connexion SSH au serveur (llarreyS)...$(NC)"
	cd $(VAGRANT_P2_DIR) && vagrant ssh llarreyS

# ==================== PARTIE 3 ====================
p3: check-docker p3-install p3-setup p3-deploy
	@echo "$(GREEN)Partie 3 lancée avec succès$(NC)"

p3-install:
	@echo "$(BLUE)Installation des outils pour la Partie 3...$(NC)"
	cd $(P3_DIR) && ./scripts/install.sh

# Les clusters K3d de p3 et du bonus publient les mêmes ports hôte (8888, 8443)
# et le même port d'API (6550) : un seul peut tourner à la fois. On arrête
# l'autre (stop, pas delete) : il redémarre avec k3d cluster start.
p3-setup: bonus-down
	@echo "$(BLUE)Configuration du cluster K3d + Argo CD...$(NC)"
	cd $(P3_DIR) && ./scripts/setup_cluster.sh

p3-deploy:
	@echo "$(BLUE)Déploiement de l'application...$(NC)"
	cd $(P3_DIR) && ./scripts/deploy_app.sh

p3-up: p3-setup p3-deploy
	@echo "$(GREEN)Cluster K3d et Argo CD démarrés$(NC)"

p3-down:
	@echo "$(YELLOW)Arrêt du cluster K3d...$(NC)"
	k3d cluster stop iot-cluster || true
	@echo "$(GREEN)Cluster K3d arrêté$(NC)"

p3-clean:
	@echo "$(RED)Nettoyage de la partie 3...$(NC)"
	cd $(P3_DIR) && ./scripts/cleanup.sh
	@echo "$(GREEN)Partie 3 nettoyée$(NC)"

check-docker:
	@echo "$(BLUE)Vérification de Docker...$(NC)"
	@docker ps >/dev/null 2>&1 || { echo "$(RED)Docker non accessible. Exécutez: newgrp docker$(NC)"; exit 1; }
	@echo "$(GREEN)Docker accessible$(NC)"

p3-status:
	@echo "$(BLUE)Statut de la Partie 3:$(NC)"
	@echo "$(YELLOW)Clusters K3d:$(NC)"
	k3d cluster list || echo "$(RED)Aucun cluster K3d$(NC)"
	@echo "$(YELLOW)Namespaces:$(NC)"
	kubectl get namespaces || echo "$(RED)Cluster non accessible$(NC)"
	@echo "$(YELLOW)Pods Argo CD:$(NC)"
	kubectl get pods -n argocd || echo "$(RED)Argo CD non déployé$(NC)"
	@echo "$(YELLOW)Application dev:$(NC)"
	kubectl get pods -n dev || echo "$(RED)Namespace dev non trouvé$(NC)"

p3-test:
	@echo "$(BLUE)Test de l'application et GitOps...$(NC)"
	cd $(P3_DIR) && ./scripts/test.sh

# ==================== BONUS ====================
bonus: check-docker bonus-install bonus-setup bonus-gitlab bonus-deploy
	@echo "$(GREEN)Bonus lancé avec succès$(NC)"

bonus-install:
	@echo "$(BLUE)Installation des outils pour le Bonus...$(NC)"
	cd $(BONUS_DIR) && ./scripts/install.sh

# p3-down libère les ports 8888/8443/6550. p1-down et p2-down libèrent la RAM :
# GitLab réclame ~6 Go, qu'une VM Vagrant allumée utiliserait.
bonus-setup: p3-down p1-down p2-down
	@echo "$(BLUE)Configuration du cluster K3d + Argo CD (Bonus)...$(NC)"
	cd $(BONUS_DIR) && ./scripts/setup_cluster.sh

bonus-gitlab: bonus-gitlab-deploy bonus-gitlab-configure
	@echo "$(GREEN)GitLab déployé et configuré$(NC)"

bonus-gitlab-deploy:
	@echo "$(BLUE)Déploiement de GitLab...$(NC)"
	cd $(BONUS_DIR) && ./scripts/deploy_gitlab.sh

bonus-gitlab-configure:
	@echo "$(BLUE)Configuration de GitLab...$(NC)"
	cd $(BONUS_DIR) && ./scripts/configure_gitlab.sh

bonus-deploy:
	@echo "$(BLUE)Déploiement de l'application via Argo CD (Bonus)...$(NC)"
	cd $(BONUS_DIR) && ./scripts/deploy_app.sh

bonus-test:
	@echo "$(BLUE)Test du Bonus GitLab...$(NC)"
	cd $(BONUS_DIR) && ./scripts/test.sh

bonus-down:
	@echo "$(YELLOW)Arrêt du cluster K3d du bonus...$(NC)"
	@k3d cluster stop iot-bonus 2>/dev/null || true

bonus-clean:
	@echo "$(RED)Nettoyage du Bonus...$(NC)"
	cd $(BONUS_DIR) && ./scripts/cleanup.sh
	@echo "$(GREEN)Bonus nettoyé$(NC)"

bonus-status:
	@echo "$(BLUE)Statut du Bonus:$(NC)"
	@echo "$(YELLOW)Clusters K3d:$(NC)"
	k3d cluster list || echo "$(RED)Aucun cluster K3d$(NC)"
	@echo "$(YELLOW)Namespaces:$(NC)"
	kubectl get namespaces || echo "$(RED)Cluster non accessible$(NC)"
	@echo "$(YELLOW)Pods GitLab:$(NC)"
	kubectl get pods -n gitlab || echo "$(RED)GitLab non déployé$(NC)"
	@echo "$(YELLOW)Pods Argo CD:$(NC)"
	kubectl get pods -n argocd || echo "$(RED)Argo CD non déployé$(NC)"
	@echo "$(YELLOW)Application dev:$(NC)"
	kubectl get pods -n dev || echo "$(RED)Namespace dev non trouvé$(NC)"

# ==================== COMMANDES GLOBALES ====================
all: p1
	@echo "$(GREEN)Toutes les parties ont été lancées avec succès!$(NC)"

clean: p1-clean p2-clean p3-clean bonus-clean cleanup-files
	@echo "$(GREEN)Nettoyage complet terminé$(NC)"

fclean: clean
	@echo "$(RED)Nettoyage forcé de toutes les parties...$(NC)"
	cd $(VAGRANT_P1_DIR) && vagrant destroy -f || true
	cd $(VAGRANT_P2_DIR) && vagrant destroy -f || true
	k3d cluster delete iot-cluster || true
	k3d cluster delete iot-bonus || true
	docker system prune -f || true
	@echo "$(GREEN)Nettoyage forcé terminé$(NC)"

cleanup-files:
	@echo "$(YELLOW)Nettoyage des fichiers temporaires...$(NC)"
	@./Tools/cleanup.sh || echo "$(YELLOW)Script de nettoyage non trouvé$(NC)"

status: p1-status p2-status p3-status bonus-status
	@echo "$(GREEN)Statut global affiché$(NC)"

# ==================== RÈGLES AVANCÉES ====================
# Vérification des prérequis
check-requirements:
	@echo "$(BLUE)Vérification des prérequis...$(NC)"
	@command -v vagrant >/dev/null 2>&1 || { echo "$(RED)Vagrant non installé$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Docker non installé$(NC)"; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "$(RED)kubectl non installé$(NC)"; exit 1; }
	@command -v k3d >/dev/null 2>&1 || { echo "$(RED)k3d non installé$(NC)"; exit 1; }
	@echo "$(GREEN)Tous les prérequis sont installés$(NC)"

# Nettoyage des logs Vagrant
logs-clean:
	@echo "$(YELLOW)Nettoyage des logs Vagrant...$(NC)"
	cd $(VAGRANT_P1_DIR) && vagrant global-status --prune || true
	cd $(VAGRANT_P2_DIR) && vagrant global-status --prune || true

# Affichage de la version des outils
check-versions:
	@echo "$(BLUE)Versions des outils:$(NC)"
	@echo "$(YELLOW)Vagrant:$(NC) $$(vagrant --version)"
	@echo "$(YELLOW)Docker:$(NC) $$(docker --version)"
	@echo "$(YELLOW)kubectl:$(NC) $$(kubectl version --client)"
	@echo "$(YELLOW)k3d:$(NC) $$(k3d --version)"
	@echo "$(YELLOW)Argo CD CLI:$(NC) $$(argocd version --client --short)"

# Vérification de conformité aux consignes
check:
	@echo "$(BLUE)Vérification de la conformité aux consignes...$(NC)"
	@./Tools/check_requirements.sh || echo "$(YELLOW)Script de vérification non trouvé$(NC)"
