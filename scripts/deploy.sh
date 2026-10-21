#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

echo "==> Verificando o repositório..."

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "ERRO: o deploy só pode ser executado na branch main."
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERRO: existem alterações locais. Faça commit ou descarte-as antes."
  exit 1
fi

git fetch origin main
git merge --ff-only origin/main

echo "==> Aplicando manifestos Kubernetes..."
sudo microk8s kubectl apply -f k8s/nginx.yaml

echo "==> Aguardando o Deployment..."
sudo microk8s kubectl rollout status deployment/nginx \
  -n homelab --timeout=120s

echo "==> Testando a aplicação..."
curl --fail --silent --show-error \
  --max-time 10 http://127.0.0.1:30080/ \
  -o /dev/null

echo "DEPLOY CONCLUIDO COM SUCESSO!"
