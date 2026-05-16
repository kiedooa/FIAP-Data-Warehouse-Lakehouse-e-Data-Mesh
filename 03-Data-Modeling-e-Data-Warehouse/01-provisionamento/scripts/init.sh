#!/usr/bin/env bash
# =============================================================================
# init.sh — Inicializa o Terraform com backend S3 remoto
# =============================================================================
# Descobre o bucket base-config-* (criado no Lab 00) e roda `terraform init`
# apontando o backend para guardar o tfstate nele.
#
# Vantagens do state remoto:
#   - sobrevive a reinício do Codespaces
#   - fica protegido contra delete acidental do diretório local
#   - permite que o aluno troque de máquina sem perder o estado
#
# Uso:
#   bash scripts/init.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

command -v aws       >/dev/null || { echo "ERRO: aws CLI nao encontrado"; exit 1; }
command -v terraform >/dev/null || { echo "ERRO: terraform nao encontrado"; exit 1; }

aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "ERRO: credenciais AWS invalidas ou expiradas. Atualize ~/.aws/credentials e tente novamente."
  exit 1
}

BUCKET="$(aws s3 ls 2>/dev/null | awk '/base-config-/ {print $3; exit}')"

if [[ -z "${BUCKET}" ]]; then
  echo "ERRO: nenhum bucket 'base-config-*' encontrado na sua conta."
  echo "Volte para o Lab 00 (00-create-codespaces) e crie o bucket antes de rodar este passo."
  exit 1
fi

echo "Bucket de state encontrado: s3://${BUCKET}"
echo "State key: 03-data-warehouse/terraform.tfstate"
echo

cd "${TF_DIR}"
terraform init -reconfigure -backend-config="bucket=${BUCKET}"
