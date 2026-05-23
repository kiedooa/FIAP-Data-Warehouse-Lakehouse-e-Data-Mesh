#!/bin/bash
set -eux

# ----------------------------------------------------------------------
# Setup do devcontainer da disciplina FIAP — Data Warehouse, Lakehouse
# e Data Mesh.
#
# Roda como postCreateCommand definido em devcontainer.json. Toda
# alteracao aqui deve ser idempotente: o aluno pode rebuildar o
# Codespaces a qualquer momento.
# ----------------------------------------------------------------------

# Atualiza o indice de pacotes apt (necessario antes de qualquer install)
sudo apt-get update -y

# Cliente PostgreSQL (psql) — usado no Lab 03.1 (Caminho B) para conectar
# no Amazon Redshift via terminal. --no-install-recommends mantem o build
# enxuto. -y aceita upgrades sem prompt.
sudo apt-get install -y --no-install-recommends postgresql-client

# Valida que o psql ficou disponivel no PATH. Se este teste falhar, o
# build do Codespaces para aqui (set -e), e o problema fica visivel no
# log da criacao em vez de dar "command not found" 30 minutos depois,
# quando o aluno estiver no meio da aula.
command -v psql >/dev/null 2>&1 || {
  echo "ERRO: psql nao foi instalado corretamente." >&2
  echo "      Tente rebuildar o Codespaces (Cmd/Ctrl+Shift+P -> Rebuild Container)." >&2
  exit 1
}
psql --version

# Serverless Framework — usado em outros labs do MBA
npm i serverless@3.39.0 -g

# Skeleton do ~/.aws para o aluno colar credenciais do Academy depois
mkdir -p ~/.aws/
cp /workspaces/FIAP-Data-Warehouse-Lakehouse-e-Data-Mesh/.devcontainer/config ~/.aws/config