-- =============================================================================
-- Lab 03.2 — Evolução 2 (Cliente ativo)
-- Arquivo: 02_opcao_snapshot.sql
-- Objetivo: modelar is_active como FATO SNAPSHOT PERIÓDICO mensal.
-- =============================================================================
--
-- ABORDAGEM (Opção B):
--   Uma linha por cliente × mês, com flag is_active.
--   Não é dimensão versionada — é FATO cujo grain é "status mensal do cliente".
--
-- CARACTERÍSTICA:
--   - Extremamente rápida para contagens agregadas (COUNT de ativos por mês).
--   - Não precisa lógica de range [valid_from, valid_to].
--   - Cresce linearmente com tempo × clientes (150k × 72 meses ≈ 10.8M linhas).
-- =============================================================================

CREATE TABLE dw_star.f_customer_status_mensal (
    data_sk        INTEGER  NOT NULL,   -- primeiro dia do mês
    customer_sk    BIGINT   NOT NULL,

    is_active      BOOLEAN  NOT NULL,

    -- Medidas auxiliares (aditivas / semi-aditivas úteis para relatórios)
    qt_pedidos_12m INTEGER  NOT NULL,   -- pedidos nos 12 meses anteriores
    vl_receita_12m DECIMAL(18,2) NOT NULL
)
DISTKEY (customer_sk)   -- co-loca vendas + status do mesmo cliente
SORTKEY (data_sk);

-- -----------------------------------------------------------------------------
-- Popular — tempo esperado: 1-2 min (10M+ linhas)
-- -----------------------------------------------------------------------------
INSERT INTO dw_star.f_customer_status_mensal
WITH meses AS (
    SELECT DISTINCT
        DATE_TRUNC('month', dt_completa) :: DATE AS mes_ref,
        CAST(TO_CHAR(DATE_TRUNC('month', dt_completa), 'YYYYMMDD') AS INTEGER) AS data_sk
    FROM dw_star.dim_data
    WHERE dt_completa BETWEEN DATE '1993-01-01' AND DATE '1998-12-31'
),
agregado_12m AS (
    SELECT
        m.mes_ref,
        m.data_sk,
        c.customer_sk,
        c.vl_saldo,
        COUNT(DISTINCT f.nr_pedido) AS qt_pedidos,
        COALESCE(SUM(f.vl_receita_liquida), 0) AS vl_receita
    FROM meses m
    CROSS JOIN dw_star.dim_customer c
    LEFT JOIN dw_star.f_vendas f
      ON f.customer_sk = c.customer_sk
     AND CAST(TO_CHAR(DATE_TRUNC('month', f.dt_envio), 'YYYYMMDD') AS INTEGER)
           BETWEEN CAST(TO_CHAR(DATEADD(month, -12, m.mes_ref), 'YYYYMMDD') AS INTEGER)
               AND CAST(TO_CHAR(DATEADD(month, -1,  m.mes_ref), 'YYYYMMDD') AS INTEGER)
    GROUP BY m.mes_ref, m.data_sk, c.customer_sk, c.vl_saldo
)
SELECT
    data_sk,
    customer_sk,
    CASE WHEN qt_pedidos > 0 AND vl_saldo > -5000 THEN TRUE ELSE FALSE END AS is_active,
    qt_pedidos  AS qt_pedidos_12m,
    vl_receita  AS vl_receita_12m
FROM agregado_12m;

ANALYZE dw_star.f_customer_status_mensal;

-- -----------------------------------------------------------------------------
-- Sanity
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*)                                                 AS linhas_total,
    COUNT(DISTINCT customer_sk)                              AS clientes_distintos,
    COUNT(DISTINCT data_sk)                                  AS meses_cobertos,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END)               AS linhas_ativas
FROM dw_star.f_customer_status_mensal;

-- Pergunta analítica: quantos ativos em junho/1996?
SELECT
    data_sk,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS qtd_ativos
FROM dw_star.f_customer_status_mensal
WHERE data_sk = 19960601
GROUP BY data_sk;
