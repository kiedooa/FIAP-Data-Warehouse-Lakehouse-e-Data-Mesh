-- =============================================================================
-- Lab 03.2 — Evolução 3 (SLA de 5s no dashboard)
-- Arquivo: 03_mv_dashboard.sql
-- Objetivo: alternativa via Materialized View pré-agregada.
-- =============================================================================
--
-- IDEIA: em vez de reescrever a fato inteira, criar uma MV com exatamente o
-- corte que o dashboard consome (ano × mês × região × segmento).
-- O dashboard passa a consultar a MV em vez da fato.
-- =============================================================================

CREATE MATERIALIZED VIEW dw_star.mv_dashboard_executivo
AUTO REFRESH YES
AS
SELECT
    d.nr_ano,
    d.nr_mes,
    g.nm_regiao,
    c.sg_segmento,
    SUM(f.vl_receita_liquida)    AS receita_liquida,
    SUM(f.vl_receita_final)      AS receita_final,
    SUM(f.qt_vendida)            AS qt_vendida,
    COUNT(*)                     AS qt_itens,
    COUNT(DISTINCT f.customer_sk) AS qt_clientes
FROM dw_star.f_vendas      f
JOIN dw_star.dim_data      d ON d.data_sk      = f.data_sk
JOIN dw_star.dim_geografia g ON g.geografia_sk = f.geografia_sk
JOIN dw_star.dim_customer  c ON c.customer_sk  = f.customer_sk
GROUP BY d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento;

-- Primeiro refresh
REFRESH MATERIALIZED VIEW dw_star.mv_dashboard_executivo;

-- -----------------------------------------------------------------------------
-- Status da MV
-- -----------------------------------------------------------------------------
SELECT
    schemaname,
    name,
    is_stale,
    autorefresh,
    state,
    total_refresh_count
FROM svv_mv_info
WHERE schemaname = 'dw_star'
  AND name       = 'mv_dashboard_executivo';

-- Tamanho físico da MV (espera-se muito pequena: ~ano × mês × 5 regiões × ~5 segmentos)
SELECT "schema", "table", size, tbl_rows
FROM svv_table_info
WHERE "schema" = 'dw_star'
  AND "table" LIKE 'mv_dashboard_executivo%';
