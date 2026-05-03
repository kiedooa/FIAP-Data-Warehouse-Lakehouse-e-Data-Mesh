-- =============================================================================
-- Lab 03.1 — Modelagem C (Star SCD2)
-- Arquivo: 04_query_ancora.sql
-- Objetivo: terceiro resultado (N3) da query-âncora, agora com histórico.
-- =============================================================================
--
-- DIFERENÇA EM RELAÇÃO A N1/N2:
--   O segmento AUTOMOBILE filtrado é o que o cliente tinha NO MOMENTO DA VENDA,
--   não o segmento atual. Clientes que em 1995 eram AUTOMOBILE mas foram
--   reclassificados depois continuam contando aqui. Clientes que em 1995 tinham
--   outro segmento mas hoje são AUTOMOBILE NÃO contam aqui.
-- =============================================================================

SELECT
    g.nm_regiao                                    AS region_name,
    ROUND(SUM(f.vl_receita_liquida), 2)            AS receita_liquida_1995_automobile,
    COUNT(*)                                       AS qtd_itens,
    COUNT(DISTINCT f.customer_sk)                  AS qtd_versoes_cliente_distintas,
    COUNT(DISTINCT c.c_custkey)                    AS qtd_clientes_distintos
FROM dw_star_scd2.f_vendas      f
JOIN dw_star_scd2.dim_customer  c ON c.customer_sk  = f.customer_sk
JOIN dw_star.dim_geografia      g ON g.geografia_sk = f.geografia_sk
JOIN dw_star.dim_data           d ON d.data_sk      = f.data_sk
WHERE d.nr_ano       = 1995
  AND c.sg_segmento  = 'AUTOMOBILE'
GROUP BY g.nm_regiao
ORDER BY receita_liquida_1995_automobile DESC;

-- =============================================================================
-- >>> ANOTE O RESULTADO como N3. Compare com N1 (oltp_mirror) e N2 (dw_star).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- BÔNUS: quantos clientes tiveram o comportamento "mudou de/para AUTOMOBILE"?
-- -----------------------------------------------------------------------------
-- Descomente e rode para ver o impacto quantitativo da decisão SCD1 vs SCD2:
--
-- -- Clientes que ERAM AUTOMOBILE em 1995 mas NÃO são hoje
-- SELECT 'EX_AUTOMOBILE' AS tipo, COUNT(*) AS qtd
-- FROM oltp_mirror.customer oc
-- JOIN dw_star_scd2.customer_history h ON h.c_custkey = oc.c_custkey
-- WHERE oc.c_mktsegment = 'AUTOMOBILE' AND h.mktsegment_new <> 'AUTOMOBILE'
--
-- UNION ALL
--
-- -- Clientes que HOJE são AUTOMOBILE mas NÃO eram em 1995
-- SELECT 'VIROU_AUTOMOBILE' AS tipo, COUNT(*) AS qtd
-- FROM oltp_mirror.customer oc
-- JOIN dw_star_scd2.customer_history h ON h.c_custkey = oc.c_custkey
-- WHERE oc.c_mktsegment <> 'AUTOMOBILE' AND h.mktsegment_new = 'AUTOMOBILE';
