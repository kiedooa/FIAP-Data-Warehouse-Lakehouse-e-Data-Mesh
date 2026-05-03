-- =============================================================================
-- Lab 03.2 — Evolução 1 (Nova fórmula de receita)
-- Arquivo: 03_mv_receita_v2.sql
-- Objetivo: criar Materialized View da v2 para consumo recorrente.
-- =============================================================================
--
-- Materialized View vs. View:
--   - View: recalcula a cada consulta. Sempre fresca, mas custo alto em joins.
--   - MV:   materializa resultado. Consumo extremamente rápido, mas pode ficar
--           "stale" até o próximo REFRESH (manual ou AUTO REFRESH).
--
-- A MV aqui pré-agrega receita v2 por ano × mês × região × segmento, que é o
-- corte mais consumido pelos dashboards.
-- =============================================================================

CREATE MATERIALIZED VIEW dw_star.mv_receita_liquida_v2_mensal
AUTO REFRESH YES
AS
SELECT
    d.nr_ano,
    d.nr_mes,
    g.nm_regiao,
    c.sg_segmento,
    SUM(
        f.vl_preco_estendido
          * (1 - f.vl_desconto_pct)
          * (1 - s.pct_comissao)
    )                                 AS vl_receita_v2,
    COUNT(*)                          AS qt_itens
FROM dw_star.f_vendas      f
JOIN dw_star.dim_data      d ON d.data_sk      = f.data_sk
JOIN dw_star.dim_geografia g ON g.geografia_sk = f.geografia_sk
JOIN dw_star.dim_customer  c ON c.customer_sk  = f.customer_sk
JOIN dw_star.dim_supplier  s ON s.supplier_sk  = f.supplier_sk
GROUP BY d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento;

-- -----------------------------------------------------------------------------
-- Primeiro REFRESH explícito (o AUTO REFRESH cuida das próximas atualizações)
-- -----------------------------------------------------------------------------
REFRESH MATERIALIZED VIEW dw_star.mv_receita_liquida_v2_mensal;

-- -----------------------------------------------------------------------------
-- Informações da MV — ver status de stale, auto refresh, último refresh
-- -----------------------------------------------------------------------------
SELECT
    schemaname,
    name,
    is_stale,
    autorefresh,
    autorewrite,
    state
FROM svv_mv_info
WHERE schemaname = 'dw_star'
  AND name       = 'mv_receita_liquida_v2_mensal';

-- -----------------------------------------------------------------------------
-- Sanity: total na MV deve bater com a view v2 agregada na mesma granularidade
-- -----------------------------------------------------------------------------
WITH mv_total AS (
    SELECT SUM(vl_receita_v2) AS total FROM dw_star.mv_receita_liquida_v2_mensal
),
view_total AS (
    SELECT SUM(vl_receita_liquida) AS total FROM dw_star.v_receita_liquida_v2
)
SELECT
    mv_total.total                                AS total_mv,
    view_total.total                              AS total_view,
    ROUND(ABS(mv_total.total - view_total.total), 2) AS diferenca_absoluta
FROM mv_total, view_total;
-- Esperado: diferenca_absoluta ≈ 0 (pode haver arredondamento < 1 centavo).
