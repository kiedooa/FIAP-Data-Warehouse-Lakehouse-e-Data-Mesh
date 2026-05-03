-- =============================================================================
-- Lab 03.2 — Evolução 3 (SLA de 5s no dashboard)
-- Arquivo: 02_redistkey.sql
-- Objetivo: recriar f_vendas com nova estratégia de distribuição e ordenação.
-- =============================================================================
--
-- HIPÓTESE: o dashboard filtra e agrupa por data/região — não por customer.
--   A DISTKEY(customer_sk) do Lab 03.1 era ótima para consultas por cliente,
--   mas não ajuda aqui. Vamos testar DISTKEY(data_sk) e sortkey composta.
--
-- CUIDADO: recriar a fato copia 6M linhas → esperar 1-3 minutos.
-- =============================================================================

-- Preservar a original para poder reverter se quiser comparar
ALTER TABLE dw_star.f_vendas RENAME TO f_vendas_original;

-- Nova fato com estratégia voltada ao dashboard
CREATE TABLE dw_star.f_vendas (
    data_sk              INTEGER       NOT NULL,
    customer_sk          BIGINT        NOT NULL,
    produto_sk           BIGINT        NOT NULL,
    supplier_sk          BIGINT        NOT NULL,
    geografia_sk         INTEGER       NOT NULL,

    nr_pedido            BIGINT        NOT NULL,
    nr_linha_pedido      INTEGER       NOT NULL,

    qt_vendida           DECIMAL(15,2) NOT NULL,
    vl_preco_estendido   DECIMAL(15,2) NOT NULL,
    vl_desconto_pct      DECIMAL(15,2) NOT NULL,
    vl_imposto_pct       DECIMAL(15,2) NOT NULL,

    vl_receita_bruta     DECIMAL(18,4) NOT NULL,
    vl_receita_liquida   DECIMAL(18,4) NOT NULL,
    vl_receita_final     DECIMAL(18,4) NOT NULL,

    fl_retornado         CHAR(1)       NOT NULL,
    fl_status_linha      CHAR(1)       NOT NULL,
    dt_envio             DATE          NOT NULL,
    dt_recebimento       DATE          NOT NULL
)
DISTKEY (data_sk)
COMPOUND SORTKEY (data_sk, geografia_sk);

-- Recarrega a partir da original
INSERT INTO dw_star.f_vendas
SELECT * FROM dw_star.f_vendas_original;

ANALYZE dw_star.f_vendas;

-- -----------------------------------------------------------------------------
-- VACUUM para consolidar zone maps (opcional em Redshift moderno, mas bom hábito)
-- -----------------------------------------------------------------------------
VACUUM dw_star.f_vendas;

-- -----------------------------------------------------------------------------
-- Verificação — contagem e distribuição
-- -----------------------------------------------------------------------------
SELECT COUNT(*) AS linhas FROM dw_star.f_vendas;
-- Esperado: 6.001.215

-- Estatística de distribuição
SELECT
    "schema",
    "table",
    diststyle,
    sortkey1,
    size,
    tbl_rows,
    skew_rows
FROM svv_table_info
WHERE "schema" = 'dw_star'
  AND "table"  = 'f_vendas';
