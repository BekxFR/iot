# CLAUDE.md

## Project Overview

Inception-of-Things (IoT) - Kubernetes administration project. Documentation in French.

- **p1/**: K3s + Vagrant - 2 VMs (chillionS + chillionSW) on 192.168.56.110-111
- **p2/**: K3s + 3 web apps - 1 VM, Traefik ingress (app1.com, app2.com, default->app3)
- **p3/**: K3d + Argo CD - GitOps from GitHub, cluster `iot-cluster`, namespaces: argocd, dev
- **bonus/**: K3d + GitLab local + Argo CD - GitOps from in-cluster GitLab, cluster `iot-bonus`, namespaces: argocd, dev, gitlab

## Commands (root Makefile)

```bash
make p1 / p1-verify / p1-ssh / p1-down / p1-clean
make p2 / p2-test / p2-ssh / p2-clean
make p3 / p3-install / p3-setup / p3-deploy / p3-test / p3-clean
make bonus / bonus-install / bonus-setup / bonus-gitlab / bonus-deploy / bonus-test / bonus-clean
make clean / fclean / status / check / check-versions
```

## Structure

Each part has `scripts/`, `confs/`, `README.md`. p1/p2 also have `Vagrantfile`.

## Networking

- p1/p2: VirtualBox 192.168.56.0/24, flannel iface auto-detected from the node IP
- p3: ports 8888 -> 80 (Ingress Traefik), 8443 -> 443 ; Argo CD par port-forward 8080:443
- bonus: same ports, GitLab internal via `gitlab-webservice-default.gitlab.svc.cluster.local:8181`

## GitOps

- p3: Argo CD -> `github.com/BekxFR/trobert-iot-argocd-app.git` -> dev namespace
- bonus: Argo CD -> local GitLab `/root/iot-app.git` -> dev namespace (HTTP, `insecure: "true"`)
- App image: `wil42/playground` (v1/v2), port 8888

## Requirements

- **p1/p2**: Vagrant + VirtualBox
- **p3**: Docker (without sudo)
- **bonus**: Docker + Helm, ~3 CPU / 6 GB RAM for GitLab

## Key constraints

- p1: VMs named `chillionS`/`chillionSW`, specific IPs, SSH without password
- p2: app2 exactly 3 replicas
- p3/bonus: app in `dev`, Argo CD in `argocd`, automated sync with prune + selfHeal
- Evaluation checklist: `Docs/CONSIGNES_POINTS_CLES.md`
