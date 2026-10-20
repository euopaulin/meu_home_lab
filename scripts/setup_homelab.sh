#!/usr/bin/env bash
#
# Preparação inicial do homelab DevOps no Ubuntu Server 24.04+
# Projetado para ser idempotente e evitar mudanças destrutivas.
#
# O script NÃO:
# - instala Docker (o servidor já usa MicroK8s/containerd);
# - atualiza ou troca a versão/canal do MicroK8s;
# - ativa o UFW automaticamente, para não cortar o acesso SSH;
# - altera configurações de rede, SSH ou autenticação.
#
set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="$(basename "$0")"
readonly REQUIRED_UBUNTU_MAJOR=24
readonly BACKUP_ROOT="${HOME}/homelab_backup"
readonly PROJECT_ROOT="${HOME}/devops-homelab"

log()  { printf '\n[INFO] %s\n' "$*"; }
warn() { printf '\n[AVISO] %s\n' "$*" >&2; }
die()  { printf '\n[ERRO] %s\n' "$*" >&2; exit 1; }

if [[ "${EUID}" -eq 0 ]]; then
  die "Execute como usuário normal, sem sudo. O script solicitará sudo quando necessário."
fi

command -v sudo >/dev/null 2>&1 || die "O comando sudo não foi encontrado."
sudo -v || die "Não foi possível obter privilégios sudo."

if [[ ! -r /etc/os-release ]]; then
  die "Não foi possível identificar o sistema operacional."
fi
# shellcheck disable=SC1091
source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
  warn "Este script foi pensado para Ubuntu. Sistema detectado: ${PRETTY_NAME:-desconhecido}."
  read -r -p "Deseja continuar mesmo assim? [s/N] " answer
  [[ "${answer,,}" == "s" || "${answer,,}" == "sim" ]] || exit 1
fi

if [[ "${ID:-}" == "ubuntu" ]]; then
  ubuntu_major="${VERSION_ID%%.*}"
  if [[ "$ubuntu_major" -lt "$REQUIRED_UBUNTU_MAJOR" ]]; then
    warn "Ubuntu ${VERSION_ID} detectado. Este script foi preparado para Ubuntu 24.04 ou superior."
    read -r -p "Deseja continuar mesmo assim? [s/N] " answer
    [[ "${answer,,}" == "s" || "${answer,,}" == "sim" ]] || exit 1
  fi
fi

printf '%s\n' "=================================================="
printf '%s\n' " Preparação do homelab DevOps — ${SCRIPT_NAME}"
printf '%s\n' " Sistema: ${PRETTY_NAME:-desconhecido}"
printf '%s\n' " Usuário: ${USER}"
printf '%s\n' "=================================================="
printf '%s\n' "Este script instala ferramentas básicas, habilita o SSH,"
printf '%s\n' "cria diretórios do projeto e exporta recursos Kubernetes."
printf '%s\n' "Ele não atualiza o MicroK8s nem ativa o firewall."
read -r -p "Continuar? [s/N] " answer
[[ "${answer,,}" == "s" || "${answer,,}" == "sim" ]] || {
  log "Operação cancelada pelo usuário."
  exit 0
}

log "Atualizando o índice de pacotes APT..."
sudo apt-get update

log "Instalando ferramentas essenciais..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  git \
  curl \
  ca-certificates \
  htop \
  tmux \
  ufw \
  unattended-upgrades \
  jq \
  tar

log "Habilitando o serviço SSH..."
sudo systemctl enable --now ssh
if ! systemctl is-active --quiet ssh; then
  die "O serviço SSH não está ativo. Confira: sudo systemctl status ssh"
fi

log "Configurando diretórios do projeto..."
mkdir -p \
  "${PROJECT_ROOT}/app" \
  "${PROJECT_ROOT}/k8s" \
  "${PROJECT_ROOT}/scripts" \
  "${PROJECT_ROOT}/docs" \
  "${BACKUP_ROOT}"

chmod 700 "${BACKUP_ROOT}"

log "Registrando informações do servidor..."
{
  printf 'Data UTC: '
  date -u '+%Y-%m-%dT%H:%M:%SZ'
  printf '\n--- OS ---\n'
  cat /etc/os-release
  printf '\n--- CPU ---\n'
  lscpu
  printf '\n--- Memória ---\n'
  free -h
  printf '\n--- Disco raiz ---\n'
  df -h /
  printf '\n--- Endereços IP ---\n'
  ip -br address
  printf '\n--- SSH ---\n'
  systemctl is-active ssh || true
} > "${BACKUP_ROOT}/server-inventory.txt"
chmod 600 "${BACKUP_ROOT}/server-inventory.txt"

log "Verificando MicroK8s existente..."
if command -v microk8s >/dev/null 2>&1; then
  if sudo microk8s status --wait-ready >/dev/null 2>&1; then
    log "MicroK8s está respondendo. Exportando recursos atuais (sem Secrets e sem dados de volumes)..."

    # Protege os arquivos: alguns recursos exportados podem conter configuração interna.
    sudo microk8s kubectl get all -A -o yaml \
      > "${BACKUP_ROOT}/kubernetes-resources.yaml"

    sudo microk8s kubectl get configmap,serviceaccount,role,rolebinding -A -o yaml \
      > "${BACKUP_ROOT}/kubernetes-config.yaml"

    chmod 600 \
      "${BACKUP_ROOT}/kubernetes-resources.yaml" \
      "${BACKUP_ROOT}/kubernetes-config.yaml"
  else
    die "MicroK8s não está respondendo. Confira: sudo microk8s status"
  fi
fi
end