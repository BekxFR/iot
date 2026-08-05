# Configuration du Repository GitHub pour GitOps

> **Important** : c'est le dépôt GitHub qui fait foi. Argo CD applique les
> manifests qu'il y trouve, pas ceux de `p3/confs/`. Toute modification faite
> dans `p3/confs/` doit être répercutée sur le dépôt, sinon les deux divergent.

## Instructions pour créer le repository

### 1. Créer un repository GitHub public

- Nom suggéré: `trobert-iot-argocd-app` (ou avec votre login)
- Description: "IoT Project - Part 3 - GitOps with Argo CD"
- Public: oui
- README: oui

### 2. Structure du repository

```
trobert-iot-argocd-app/
├── deployment.yaml
├── service.yaml
├── ingress.yaml
└── README.md
```

### 3. Contenu des fichiers

#### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wil-playground
  namespace: dev
  labels:
    app: wil-playground
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wil-playground
  template:
    metadata:
      labels:
        app: wil-playground
    spec:
      containers:
        - name: wil-playground
          image: wil42/playground:v1 # Changez v1 en v2 pour tester GitOps
          ports:
            - containerPort: 8888
          resources:
            requests:
              memory: "64Mi"
              cpu: "50m"
            limits:
              memory: "128Mi"
              cpu: "100m"
```

#### service.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: wil-playground-service
  namespace: dev
  labels:
    app: wil-playground
spec:
  selector:
    app: wil-playground
  ports:
    - protocol: TCP
      port: 8888
      targetPort: 8888
  type: ClusterIP
```

#### ingress.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wil-playground-ingress
  namespace: dev
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: wil-playground-service
                port:
                  number: 8888
```

### 4. Commandes Git

```bash
# Cloner le repository
git clone https://github.com/BekxFR/trobert-iot-argocd-app.git
cd trobert-iot-argocd-app

# Copier les fichiers
cp ../p3/confs/deployment.yaml .
cp ../p3/confs/service.yaml .
cp ../p3/confs/ingress.yaml .

# Commit initial
git add .
git commit -m "Initial deployment - v1"
git push origin main

# Pour tester le GitOps (changement de version)
sed -i 's/wil42\/playground:v1/wil42\/playground:v2/g' deployment.yaml
git add deployment.yaml
git commit -m "Update to v2"
git push origin main
```

### 5. Configuration Argo CD

Modifiez le fichier `confs/application.yaml` avec votre URL de repository:

```yaml
spec:
  source:
    repoURL: https://github.com/BekxFR/trobert-iot-argocd-app.git
```

### 6. Test du GitOps

1. Changez v1 en v2 dans deployment.yaml
2. Commit et push
3. Argo CD synchronise automatiquement
4. Vérifiez: `curl http://localhost:8888`
