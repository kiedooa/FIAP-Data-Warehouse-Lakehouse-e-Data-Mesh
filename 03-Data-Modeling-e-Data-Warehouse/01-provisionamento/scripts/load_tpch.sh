#!/usr/bin/env bash
# =============================================================================
# load_tpch.sh — Copia TPC-H SF10 para o bucket do aluno (S3-to-S3, server-side)
# =============================================================================
# Executar APÓS terraform apply. Estratégia rápida e enxuta:
#   1. Lê outputs do Terraform (bucket de destino, região, glue db)
#   2. Faz S3-to-S3 copy dos 8 arquivos .tbl do bucket público AWS para o
#      bucket do aluno — sem passar pela rede local nem por Python
#   3. Gera customer_history sintética em Python (Pandas) — pequeno, ~75k linhas
#   4. Registra as 9 tabelas no Glue Data Catalog (formato CSV delimitado por "|")
#
# As tabelas TPC-H ficam em formato .tbl (texto delimitado por "|") e o
# Redshift COPY lê esse formato direto via FORMAT AS CSV DELIMITER '|'.
# Sem conversão para Parquet — simplifica e fica significativamente mais rápido.
#
# Uso:
#   bash 01-provisionamento/scripts/load_tpch.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# -----------------------------------------------------------------------------
# Pré-requisitos
# -----------------------------------------------------------------------------
command -v aws       >/dev/null || { echo "ERRO: aws CLI nao encontrado"; exit 1; }
command -v terraform >/dev/null || { echo "ERRO: terraform nao encontrado"; exit 1; }
command -v python3   >/dev/null || { echo "ERRO: python3 nao encontrado"; exit 1; }

# venv local apenas para gerar customer_history (~75k linhas, leve).
VENV_DIR="${TF_DIR}/.venv"
if [[ ! -f "${VENV_DIR}/bin/activate" ]]; then
  rm -rf "${VENV_DIR}"
  echo ">> Criando venv em ${VENV_DIR}..."
  python3 -m venv "${VENV_DIR}" || {
    echo "ERRO: 'python3 -m venv' falhou. No Ubuntu rode: sudo apt-get install -y python3-venv"
    exit 1
  }
fi
# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"

python -c "import pandas, pyarrow" 2>/dev/null || {
  echo ">> Instalando pandas + pyarrow no venv..."
  python -m pip install --quiet --upgrade pip
  python -m pip install --quiet pandas pyarrow
}

# -----------------------------------------------------------------------------
# Outputs do Terraform (fonte unica de verdade)
# -----------------------------------------------------------------------------
cd "${TF_DIR}"

if ! terraform output -raw s3_bucket_name >/dev/null 2>&1; then
  echo "ERRO: outputs do Terraform indisponiveis em ${TF_DIR}"
  echo "      Rode 'bash scripts/init.sh && terraform apply' antes deste script."
  exit 1
fi

BUCKET=$(terraform output -raw s3_bucket_name)
REGION=$(terraform output -raw region)
GLUE_DB=$(terraform output -raw glue_database_name)

# Multipart agressivo: acelera S3-to-S3 e o get-bucket-versioning de leitura
aws configure set default.s3.max_concurrent_requests 10
aws configure set default.s3.multipart_threshold     64MB
aws configure set default.s3.multipart_chunksize     32MB

echo "══════════════════════════════════════════════════════════════════"
echo " TPC-H SF10 Loader (S3-to-S3 server-side copy)"
echo "══════════════════════════════════════════════════════════════════"
echo " Destino : s3://${BUCKET}/raw/tpch/"
echo " Regiao  : ${REGION}"
echo " Glue DB : ${GLUE_DB}"
echo "══════════════════════════════════════════════════════════════════"

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT
export WORK_DIR
echo ">> Workspace temporario: ${WORK_DIR}"

# -----------------------------------------------------------------------------
# S3-to-S3 copy (server-side) do bucket publico para o bucket do aluno
# -----------------------------------------------------------------------------
# O bucket publico s3://redshift-downloads/ permite s3:GetObject anonimo.
# Para copiar entre buckets em paralelo, usamos `aws s3 cp` com --source-region.
# Como o bucket publico esta em us-east-1, mesma regiao do aluno, a copia eh
# server-side e o trafego nao atravessa a internet.
# -----------------------------------------------------------------------------
TABLES=(nation region customer supplier part partsupp orders lineitem)

echo ""
echo ">> Copiando .tbl do bucket publico (server-side, mesma regiao, em paralelo)..."
SRC_BUCKET="redshift-downloads"
SRC_PREFIX="TPC-H/2.18/10GB"

LOG_DIR="${WORK_DIR}/cp-logs"
mkdir -p "${LOG_DIR}"

copy_one() {
  local t=$1
  local src="s3://${SRC_BUCKET}/${SRC_PREFIX}/${t}.tbl"
  local dst="s3://${BUCKET}/raw/tpch/${t}/${t}.tbl"
  local log="${LOG_DIR}/${t}.log"
  local start=$(date +%s)
  if aws s3 cp "${src}" "${dst}" --copy-props none --no-progress >"${log}" 2>&1; then
    local elapsed=$(( $(date +%s) - start ))
    printf "   ✔ %-10s %ss\n" "${t}" "${elapsed}"
  else
    local elapsed=$(( $(date +%s) - start ))
    printf "   ✘ %-10s %ss (FALHOU - veja %s)\n" "${t}" "${elapsed}" "${log}"
    return 1
  fi
}

# Dispara as 8 copias em paralelo. multipart_concurrent_requests=10 (default
# do script) faz cada copia internamente paralelizar chunks da tabela grande.
overall_start=$(date +%s)
pids=()
for t in "${TABLES[@]}"; do
  copy_one "${t}" &
  pids+=($!)
done

failed=0
for pid in "${pids[@]}"; do
  wait "${pid}" || failed=1
done
overall_elapsed=$(( $(date +%s) - overall_start ))

if [[ ${failed} -ne 0 ]]; then
  echo "ERRO: alguma copia falhou — abortando."
  exit 1
fi
echo "   total da copia paralela: ${overall_elapsed}s"

# -----------------------------------------------------------------------------
# Geracao da customer_history sintetica
# -----------------------------------------------------------------------------
# Para gerar a customer_history precisamos da customer real. Como nao queremos
# baixar customer.tbl inteiro (243 MB), usamos a copia ja no bucket do aluno:
# baixar so customer.tbl (243 MB cabe em RAM tranquilo) e gerar o subset.
# -----------------------------------------------------------------------------
echo ""
echo ">> Baixando customer.tbl para gerar customer_history sintetica..."
aws s3 cp "s3://${BUCKET}/raw/tpch/customer/customer.tbl" "${WORK_DIR}/customer.tbl" --no-progress
ls -lh "${WORK_DIR}/customer.tbl"

echo ""
echo ">> Gerando customer_history (5% dos clientes, seed 42)..."
python - <<'PYEOF'
import os
import random
import pandas as pd

WORK_DIR = os.environ["WORK_DIR"]
random.seed(42)

cols = ["c_custkey","c_name","c_address","c_nationkey","c_phone",
        "c_acctbal","c_mktsegment","c_comment","__trailing"]
cust = pd.read_csv(
    os.path.join(WORK_DIR, "customer.tbl"),
    sep="|", header=None, names=cols, engine="c",
)[["c_custkey","c_mktsegment"]]

print(f"   - customer base: {len(cust):,} clientes")

sample = cust.sample(frac=0.05, random_state=42).copy()

segments = ["BUILDING","AUTOMOBILE","MACHINERY","HOUSEHOLD","FURNITURE"]

def pick_new(old):
    return random.choice([s for s in segments if s != old])

sample["mktsegment_new"] = sample["c_mktsegment"].apply(pick_new)

dates = pd.date_range("1996-01-01","1998-12-31", freq="D")
sample["valid_from"] = [random.choice(dates).date() for _ in range(len(sample))]

history = sample[["c_custkey","mktsegment_new","valid_from"]].reset_index(drop=True)

# Escreve em formato .tbl (CSV delimitado por "|", consistente com TPC-H)
out_path = os.path.join(WORK_DIR, "customer_history.tbl")
history.to_csv(out_path, sep="|", header=False, index=False, date_format="%Y-%m-%d")

print(f"   - customer_history: {len(history):,} reclassificacoes")
print(f"     -> {out_path}")
PYEOF

aws s3 cp "${WORK_DIR}/customer_history.tbl" "s3://${BUCKET}/raw/tpch/customer_history/customer_history.tbl" --no-progress

# -----------------------------------------------------------------------------
# Registro no Glue Data Catalog
# -----------------------------------------------------------------------------
echo ""
echo ">> Registrando tabelas no Glue Data Catalog (${GLUE_DB})..."

register_glue_table() {
  local table=$1
  local columns_json=$2
  local location="s3://${BUCKET}/raw/tpch/${table}/"

  aws glue delete-table \
    --database-name "${GLUE_DB}" \
    --name "${table}" \
    --region "${REGION}" 2>/dev/null || true

  aws glue create-table \
    --database-name "${GLUE_DB}" \
    --region "${REGION}" \
    --table-input "{
      \"Name\": \"${table}\",
      \"TableType\": \"EXTERNAL_TABLE\",
      \"Parameters\": {
        \"classification\": \"csv\",
        \"delimiter\": \"|\",
        \"has_encrypted_data\": \"false\"
      },
      \"StorageDescriptor\": {
        \"Columns\": ${columns_json},
        \"Location\": \"${location}\",
        \"InputFormat\": \"org.apache.hadoop.mapred.TextInputFormat\",
        \"OutputFormat\": \"org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat\",
        \"SerdeInfo\": {
          \"SerializationLibrary\": \"org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe\",
          \"Parameters\": {\"field.delim\": \"|\"}
        }
      }
    }" >/dev/null
  echo "   - ${table}"
}

register_glue_table nation '[
  {"Name":"n_nationkey","Type":"int"},
  {"Name":"n_name","Type":"string"},
  {"Name":"n_regionkey","Type":"int"},
  {"Name":"n_comment","Type":"string"}
]'

register_glue_table region '[
  {"Name":"r_regionkey","Type":"int"},
  {"Name":"r_name","Type":"string"},
  {"Name":"r_comment","Type":"string"}
]'

register_glue_table customer '[
  {"Name":"c_custkey","Type":"bigint"},
  {"Name":"c_name","Type":"string"},
  {"Name":"c_address","Type":"string"},
  {"Name":"c_nationkey","Type":"int"},
  {"Name":"c_phone","Type":"string"},
  {"Name":"c_acctbal","Type":"double"},
  {"Name":"c_mktsegment","Type":"string"},
  {"Name":"c_comment","Type":"string"}
]'

register_glue_table supplier '[
  {"Name":"s_suppkey","Type":"bigint"},
  {"Name":"s_name","Type":"string"},
  {"Name":"s_address","Type":"string"},
  {"Name":"s_nationkey","Type":"int"},
  {"Name":"s_phone","Type":"string"},
  {"Name":"s_acctbal","Type":"double"},
  {"Name":"s_comment","Type":"string"}
]'

register_glue_table part '[
  {"Name":"p_partkey","Type":"bigint"},
  {"Name":"p_name","Type":"string"},
  {"Name":"p_mfgr","Type":"string"},
  {"Name":"p_brand","Type":"string"},
  {"Name":"p_type","Type":"string"},
  {"Name":"p_size","Type":"int"},
  {"Name":"p_container","Type":"string"},
  {"Name":"p_retailprice","Type":"double"},
  {"Name":"p_comment","Type":"string"}
]'

register_glue_table partsupp '[
  {"Name":"ps_partkey","Type":"bigint"},
  {"Name":"ps_suppkey","Type":"bigint"},
  {"Name":"ps_availqty","Type":"int"},
  {"Name":"ps_supplycost","Type":"double"},
  {"Name":"ps_comment","Type":"string"}
]'

register_glue_table orders '[
  {"Name":"o_orderkey","Type":"bigint"},
  {"Name":"o_custkey","Type":"bigint"},
  {"Name":"o_orderstatus","Type":"string"},
  {"Name":"o_totalprice","Type":"double"},
  {"Name":"o_orderdate","Type":"date"},
  {"Name":"o_orderpriority","Type":"string"},
  {"Name":"o_clerk","Type":"string"},
  {"Name":"o_shippriority","Type":"int"},
  {"Name":"o_comment","Type":"string"}
]'

register_glue_table lineitem '[
  {"Name":"l_orderkey","Type":"bigint"},
  {"Name":"l_partkey","Type":"bigint"},
  {"Name":"l_suppkey","Type":"bigint"},
  {"Name":"l_linenumber","Type":"int"},
  {"Name":"l_quantity","Type":"double"},
  {"Name":"l_extendedprice","Type":"double"},
  {"Name":"l_discount","Type":"double"},
  {"Name":"l_tax","Type":"double"},
  {"Name":"l_returnflag","Type":"string"},
  {"Name":"l_linestatus","Type":"string"},
  {"Name":"l_shipdate","Type":"date"},
  {"Name":"l_commitdate","Type":"date"},
  {"Name":"l_receiptdate","Type":"date"},
  {"Name":"l_shipinstruct","Type":"string"},
  {"Name":"l_shipmode","Type":"string"},
  {"Name":"l_comment","Type":"string"}
]'

register_glue_table customer_history '[
  {"Name":"c_custkey","Type":"bigint"},
  {"Name":"mktsegment_new","Type":"string"},
  {"Name":"valid_from","Type":"date"}
]'

echo ""
echo "══════════════════════════════════════════════════════════════════"
echo " TPC-H SF10 carregado no S3 com sucesso!"
echo "══════════════════════════════════════════════════════════════════"
aws s3 ls "s3://${BUCKET}/raw/tpch/" --recursive --human-readable --summarize | tail -15
echo ""
echo " Proximo passo: abra 02-modelagem-e-carga/README.md"
echo "══════════════════════════════════════════════════════════════════"
