-- =============================================================================
-- Lab 03.1 — Modelagem B (Star SCD1)
-- Arquivo: 05_query_ancora.sql
-- Objetivo: segundo resultado (N2) da query-âncora, no star schema SCD1.
-- =============================================================================
--
-- COMPARAÇÃO com a Modelagem A:
--   - Join de 3 tabelas (f_vendas → dim_customer → dim_geografia + filtro via dim_data)
--     vs. 5 joins no OLTP mirror.
--   - Receita líquida já está MATERIALIZADA como coluna (vl_receita_liquida).
--   - Segmento AUTOMOBILE ainda vem do estado ATUAL (SCD1 = sobrescrita).
--   - Filtro por ano usa dim_data (contrato semântico), não EXTRACT(year FROM ...).
--
-- EXPECTATIVA: N2 ≈ N1 (pequena diferença só por arredondamento float/decimal).
-- =============================================================================

SELECT
    g.nm_regiao                                    AS region_name,
    ROUND(SUM(f.vl_receita_liquida), 2)            AS receita_liquida_1995_automobile,
    COUNT(*)                                       AS qtd_itens,
    COUNT(DISTINCT f.customer_sk)                  AS qtd_clientes_distintos
FROM dw_star.f_vendas    f
JOIN dw_star.dim_customer  c ON c.customer_sk  = f.customer_sk
JOIN dw_star.dim_geografia g ON g.geografia_sk = f.geografia_sk
JOIN dw_star.dim_data      d ON d.data_sk      = f.data_sk
WHERE d.nr_ano       = 1995
  AND c.sg_segmento  = 'AUTOMOBILE'
GROUP BY g.nm_regiao
ORDER BY receita_liquida_1995_automobile DESC;

-- -----------------------------------------------------------------------------
-- BÔNUS 1: comparação com EXPLAIN — veja como o star schema simplifica o plano
-- -----------------------------------------------------------------------------
-- EXPLAIN
-- SELECT g.nm_regiao, SUM(f.vl_receita_liquida)
-- FROM dw_star.f_vendas f
-- JOIN dw_star.dim_customer  c ON c.customer_sk  = f.customer_sk
-- JOIN dw_star.dim_geografia g ON g.geografia_sk = f.geografia_sk
-- JOIN dw_star.dim_data      d ON d.data_sk      = f.data_sk
-- WHERE d.nr_ano = 1995 AND c.sg_segmento = 'AUTOMOBILE'
-- GROUP BY g.nm_regiao;
--
-- Observe como o filtro por d.nr_ano = 1995 pode ser empurrado para a fato
-- via sort key (data_sk), e como dim_geografia com DISTSTYLE ALL evita
-- redistribuição.

-- =============================================================================
-- >>> ANOTE O RESULTADO como N2. Compare com N1 (oltp_mirror).
-- =============================================================================
