-- =============================================================================
-- Lab 03.1 — Modelagem A (Espelho OLTP)
-- Arquivo: 02_copy_tables.sql
-- Objetivo: carregar as 8 tabelas do S3 usando COPY
-- =============================================================================
--
-- ANTES DE EXECUTAR: substitua <SEU_ACCOUNT_ID> pelo seu Account ID (12 dígitos).
-- Obtenha com:
--     aws sts get-caller-identity --query Account --output text
--
-- Alternativa: rodar 'terraform output -raw s3_bucket_name' na pasta
-- 01-provisionamento/ para obter o nome completo do bucket.
-- =============================================================================
--
-- Observação sobre IAM_ROLE default:
-- Configuramos default_iam_role_arn = LabRole no Terraform, então podemos usar
-- "IAM_ROLE default" em vez de colar o ARN completo em cada COPY.
-- =============================================================================

-- Região pequena — carrega rápido
COPY oltp_mirror.region
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/region/'
IAM_ROLE default
FORMAT AS PARQUET;

COPY oltp_mirror.nation
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/nation/'
IAM_ROLE default
FORMAT AS PARQUET;

-- Customer — 150k linhas
COPY oltp_mirror.customer
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/customer/'
IAM_ROLE default
FORMAT AS PARQUET;

-- Supplier — 10k linhas
COPY oltp_mirror.supplier
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/supplier/'
IAM_ROLE default
FORMAT AS PARQUET;

-- Part — 200k linhas
COPY oltp_mirror.part
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/part/'
IAM_ROLE default
FORMAT AS PARQUET;

-- PartSupp — 800k linhas
COPY oltp_mirror.partsupp
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/partsupp/'
IAM_ROLE default
FORMAT AS PARQUET;

-- Orders — 1.5M linhas
COPY oltp_mirror.orders
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/orders/'
IAM_ROLE default
FORMAT AS PARQUET;

-- LineItem — 6M linhas (maior tabela, ~2-3 min)
COPY oltp_mirror.lineitem
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/lineitem/'
IAM_ROLE default
FORMAT AS PARQUET;

-- -----------------------------------------------------------------------------
-- Análise das tabelas — atualiza estatísticas para o otimizador
-- -----------------------------------------------------------------------------
ANALYZE oltp_mirror.region;
ANALYZE oltp_mirror.nation;
ANALYZE oltp_mirror.customer;
ANALYZE oltp_mirror.supplier;
ANALYZE oltp_mirror.part;
ANALYZE oltp_mirror.partsupp;
ANALYZE oltp_mirror.orders;
ANALYZE oltp_mirror.lineitem;

-- -----------------------------------------------------------------------------
-- Sanity checks — contagens devem bater com TPC-H SF1
-- -----------------------------------------------------------------------------
SELECT 'region'   AS tbl, COUNT(*) AS linhas, 5        AS esperado FROM oltp_mirror.region
UNION ALL
SELECT 'nation'   AS tbl, COUNT(*) AS linhas, 25       AS esperado FROM oltp_mirror.nation
UNION ALL
SELECT 'customer' AS tbl, COUNT(*) AS linhas, 150000   AS esperado FROM oltp_mirror.customer
UNION ALL
SELECT 'supplier' AS tbl, COUNT(*) AS linhas, 10000    AS esperado FROM oltp_mirror.supplier
UNION ALL
SELECT 'part'     AS tbl, COUNT(*) AS linhas, 200000   AS esperado FROM oltp_mirror.part
UNION ALL
SELECT 'partsupp' AS tbl, COUNT(*) AS linhas, 800000   AS esperado FROM oltp_mirror.partsupp
UNION ALL
SELECT 'orders'   AS tbl, COUNT(*) AS linhas, 1500000  AS esperado FROM oltp_mirror.orders
UNION ALL
SELECT 'lineitem' AS tbl, COUNT(*) AS linhas, 6001215  AS esperado FROM oltp_mirror.lineitem
ORDER BY tbl;
