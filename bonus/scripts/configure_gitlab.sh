#!/bin/bash

echo "=== Configuration de GitLab - Bonus ==="

NAMESPACE_GITLAB="gitlab"
NAMESPACE_ARGOCD="argocd"
GITLAB_PROJECT="iot-app"
LOCAL_PORT=30080

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BONUS_DIR="$(dirname "$SCRIPT_DIR")"

# Verification du cluster
if ! kubectl get nodes >/dev/null 2>&1; then
    echo "[FAIL] Cluster K3d non accessible."
    exit 1
fi

# Verification que GitLab est deploye
if ! kubectl get pods -n $NAMESPACE_GITLAB -l app=webservice 2>/dev/null | grep -q "Running"; then
    echo "[FAIL] GitLab webservice non pret. Lancez d'abord : ./scripts/deploy_gitlab.sh"
    exit 1
fi

# 1. Recuperer le mot de passe root GitLab
echo "Recuperation du mot de passe root GitLab..."
ROOT_PASSWORD=$(kubectl get secret gitlab-gitlab-initial-root-password -n $NAMESPACE_GITLAB -o jsonpath='{.data.password}' | base64 -d)
if [ -z "$ROOT_PASSWORD" ]; then
    echo "[FAIL] Impossible de recuperer le mot de passe root GitLab"
    exit 1
fi
echo "[OK] Mot de passe root recupere"

# 2. Port-forward vers GitLab
echo "Demarrage du port-forward vers GitLab (port $LOCAL_PORT)..."
kubectl port-forward svc/gitlab-webservice-default -n $NAMESPACE_GITLAB $LOCAL_PORT:8181 &
PF_PID=$!
sleep 5

# Fonction de nettoyage
# WORKDIR (et non TMPDIR, variable d'environnement standard) : un exit avant
# mktemp aurait sinon supprime le repertoire temporaire du systeme.
WORKDIR=""
cleanup() {
    echo "Nettoyage..."
    kill $PF_PID 2>/dev/null || true
    if [ -n "$WORKDIR" ] && [ -d "$WORKDIR" ]; then
        rm -rf "$WORKDIR"
    fi
}
trap cleanup EXIT

# 3. Attendre que l'API GitLab reponde
echo "Attente de l'API GitLab..."
for i in $(seq 1 60); do
    if curl -s "http://localhost:$LOCAL_PORT/api/v4/version" 2>/dev/null | grep -q "version"; then
        echo "[OK] API GitLab prete"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "[FAIL] Timeout: API GitLab non disponible apres 10 minutes"
        exit 1
    fi
    echo "  ... Attente de l'API ($i/60)"
    sleep 10
done

# 4. Creer un Personal Access Token via gitlab-rails runner
echo "Creation d'un Personal Access Token..."
# Le pod toolbox est la voie privilegiee, mais son absence ne doit pas etre
# fatale : le repli OAuth ci-dessous sait aussi obtenir un token. Un `exit 1`
# ici rendait ce repli inatteignable.
TOOLBOX_POD=$(kubectl get pods -n $NAMESPACE_GITLAB -l app=toolbox -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
TOKEN=""
if [ -z "$TOOLBOX_POD" ]; then
    echo "[WARN] Pod toolbox absent : passage direct au repli OAuth."
else
    TOKEN=$(kubectl exec "$TOOLBOX_POD" -n $NAMESPACE_GITLAB -c toolbox -- gitlab-rails runner "
token = User.find_by_username('root').personal_access_tokens.create!(
  scopes: [:api, :read_repository, :write_repository],
  name: 'iot-token',
  expires_at: 365.days.from_now
)
puts token.token
" 2>/dev/null | tail -1 | tr -d '\r\n')
fi

if [ -z "$TOKEN" ]; then
    echo "Token via rails runner echoue, tentative via API..."
    # Fallback: utiliser l'API avec login/password
    TOKEN=$(curl -s -X POST "http://localhost:$LOCAL_PORT/oauth/token" \
        -d "grant_type=password&username=root&password=$ROOT_PASSWORD" 2>/dev/null | \
        jq -r '.access_token // empty')
    if [ -z "$TOKEN" ]; then
        echo "[FAIL] Impossible de creer un token d'acces"
        exit 1
    fi
    TOKEN_HEADER="Authorization: Bearer $TOKEN"
    echo "[OK] Token OAuth obtenu"
else
    TOKEN_HEADER="PRIVATE-TOKEN: $TOKEN"
    echo "[OK] Personal Access Token cree"
fi

# 5. Creer le projet GitLab
echo "Creation du projet '$GITLAB_PROJECT'..."
CREATE_RESP=$(curl -s -X POST "http://localhost:$LOCAL_PORT/api/v4/projects" \
    -H "$TOKEN_HEADER" \
    -d "name=$GITLAB_PROJECT&visibility=public&initialize_with_readme=false")

PROJECT_ID=$(echo "$CREATE_RESP" | jq -r '.id // empty')
if [ -z "$PROJECT_ID" ]; then
    # Le projet existe peut-etre deja
    PROJECT_ID=$(curl -s "http://localhost:$LOCAL_PORT/api/v4/projects?search=$GITLAB_PROJECT" \
        -H "$TOKEN_HEADER" | jq -r '.[0].id // empty')
    if [ -z "$PROJECT_ID" ]; then
        echo "[FAIL] Impossible de creer ou trouver le projet"
        echo "Reponse: $CREATE_RESP"
        exit 1
    fi
    echo "[OK] Projet existant trouve (ID: $PROJECT_ID)"
else
    echo "[OK] Projet cree (ID: $PROJECT_ID)"
fi

# 6. Cloner, copier les manifestes, push vers GitLab
echo "Push des manifestes vers GitLab..."
WORKDIR=$(mktemp -d)
cd "$WORKDIR"

git init
git config user.email "root@gitlab.local"
git config user.name "Administrator"

# Copier les manifestes (sans application.yaml qui reste local)
cp "$BONUS_DIR/confs/deployment.yaml" .
cp "$BONUS_DIR/confs/service.yaml" .
cp "$BONUS_DIR/confs/ingress.yaml" .

git add .
git commit -m "Initial manifests for wil-playground v1"

# Determiner le header d'authentification pour git
if echo "$TOKEN_HEADER" | grep -q "PRIVATE-TOKEN"; then
    GIT_URL="http://root:${TOKEN}@localhost:${LOCAL_PORT}/root/${GITLAB_PROJECT}.git"
else
    GIT_URL="http://root:${ROOT_PASSWORD}@localhost:${LOCAL_PORT}/root/${GITLAB_PROJECT}.git"
fi

git remote add origin "$GIT_URL"
git branch -M main

if git push -u origin main; then
    echo "[OK] Manifestes pushes vers GitLab"
else
    echo "[FAIL] Erreur lors du push vers GitLab"
    exit 1
fi

cd "$BONUS_DIR"

# 7. Enregistrer le repo dans Argo CD via Secret
echo "Enregistrement du repo GitLab dans Argo CD..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: gitlab-repo
  namespace: $NAMESPACE_ARGOCD
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: http://gitlab-webservice-default.gitlab.svc.cluster.local:8181/root/${GITLAB_PROJECT}.git
  insecure: "true"
EOF

echo "[OK] Repo enregistre dans Argo CD"
echo "Configuration de GitLab terminee. Prochaine etape : ./scripts/deploy_app.sh"
