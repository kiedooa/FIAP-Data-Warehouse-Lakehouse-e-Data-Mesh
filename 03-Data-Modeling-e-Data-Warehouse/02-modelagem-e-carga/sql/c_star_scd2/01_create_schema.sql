-- =============================================================================
-- Lab 03.1 — Modelagem C (Star Schema com SCD Tipo 2)
-- Arquivo: 01_create_schema.sql
-- Objetivo: schema isolado para exercitar SCD Tipo 2 com customer_history.
-- =============================================================================
--
-- IDEIA: reaproveitar as dimensões do dw_star (geografia, produto, supplier, data)
-- para não precisar recriá-las, e construir SOMENTE dim_customer e f_vendas aqui,
-- com histórico de segmento preservado.
-- =============================================================================

DROP SCHEMA IF EXISTS dw_star_scd2 CASCADE;
CREATE SCHEMA dw_star_scd2;

-- -----------------------------------------------------------------------------
-- Carregar customer_history (gerada pelo load_tpch.sh) para uma staging
-- -----------------------------------------------------------------------------
CREATE TABLE dw_star_scd2.customer_history (
    c_custkey       BIGINT      NOT NULL,
    mktsegment_new  VARCHAR(10) NOT NULL,
    valid_from      DATE        NOT NULL
)
DISTSTYLE AUTO
SORTKEY (c_custkey);

-- ATENÇÃO: substitua <SEU_ACCOUNT_ID> antes de rodar
COPY dw_star_scd2.customer_history
FROM 's3://dw-lab-<SEU_ACCOUNT_ID>/raw/tpch/customer_history/'
IAM_ROLE default
FORMAT AS PARQUET;

ANALYZE dw_star_scd2.customer_history;

-- Verificação: esperado ~7500 linhas (5% de 150k)
SELECT COUNT(*) AS reclassificacoes FROM dw_star_scd2.customer_history;
