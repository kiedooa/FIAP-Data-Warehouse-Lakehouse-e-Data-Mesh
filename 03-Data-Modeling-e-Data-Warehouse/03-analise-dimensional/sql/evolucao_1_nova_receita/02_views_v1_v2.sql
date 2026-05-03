-- =============================================================================
-- Lab 03.2 — Evolução 1 (Nova fórmula de receita)
-- Arquivo: 02_views_v1_v2.sql
-- Objetivo: criar as views v1 (preservação) e v2 (nova fórmula).
-- =============================================================================
--
-- v1 = receita_liquida = extendedprice * (1 - discount)
-- v2 = receita_liquida_v2 = extendedprice * (1 - discount) * (1 - pct_comissao)
--
-- Ambas coexistem. v1 NÃO é removida — dashboards antigos continuam funcionando.
-- =============================================================================

CREATE OR REPLACE VIEW dw_star.v_receita_liquida_v1 AS
SELECT
    f.data_sk,
    f.customer_sk,
    f.produto_sk,
    f.supplier_sk,
    f.geografia_sk,
    f.nr_pedido,
    f.nr_linha_pedido,
    f.qt_vendida,
    f.vl_receita_liquida       AS vl_receita_liquida,
    'v1'                       AS versao_formula
FROM dw_star.f_vendas f;

COMMENT ON VIEW dw_star.v_receita_liquida_v1 IS
    'Receita liquida — formula original: extendedprice * (1 - discount). Preservada para comparabilidade historica.';

CREATE OR REPLACE VIEW dw_star.v_receita_liquida_v2 AS
SELECT
    f.data_sk,
    f.customer_sk,
    f.produto_sk,
    f.supplier_sk,
    f.geografia_sk,
    f.nr_pedido,
    f.nr_linha_pedido,
    f.qt_vendida,
    (f.vl_preco_estendido
       * (1 - f.vl_desconto_pct)
       * (1 - s.pct_comissao))   AS vl_receita_liquida,
    'v2'                         AS versao_formula
FROM dw_star.f_vendas     f
JOIN dw_star.dim_supplier s ON s.supplier_sk = f.supplier_sk;

COMMENT ON VIEW dw_star.v_receita_liquida_v2 IS
    'Receita liquida v2 — aplica comissao do marketplace por fornecedor.';

-- -----------------------------------------------------------------------------
-- Verificação rápida
-- -----------------------------------------------------------------------------
SELECT 'v1_total' AS serie, ROUND(SUM(vl_receita_liquida), 2) AS valor
FROM dw_star.v_receita_liquida_v1
UNION ALL
SELECT 'v2_total', ROUND(SUM(vl_receita_liquida), 2)
FROM dw_star.v_receita_liquida_v2;

-- v2_total deve ser sempre MENOR que v1_total (porque desconta comissão).
-- A diferença percentual reflete a comissão média ponderada pela receita.
