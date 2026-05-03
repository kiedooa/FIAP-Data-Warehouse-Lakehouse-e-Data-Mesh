-- =============================================================================
-- Lab 03.1 — Modelagem A (Espelho OLTP)
-- Arquivo: 03_query_ancora.sql
-- Objetivo: primeiro resultado (N1) da query-âncora, no modelo OLTP puro.
-- =============================================================================
--
-- PERGUNTA DE NEGÓCIO:
--   "Qual foi a receita líquida total do segmento AUTOMOBILE no ano de 1995,
--    agrupada por região do cliente?"
--
-- CARACTERÍSTICAS DESTA QUERY:
--   - Join de 4 tabelas (lineitem → orders → customer → nation → region): 5 joins
--   - Filtros espalhados por tabelas diferentes (o_orderdate em orders,
--     c_mktsegment em customer)
--   - Receita líquida calculada on-the-fly (l_extendedprice * (1 - l_discount))
--   - Segmento AUTOMOBILE lido do ESTADO ATUAL da tabela customer
--     (ou seja, se houve reclassificação depois de 1995, a venda será
--      atribuída ao segmento ATUAL do cliente — não ao de 1995)
-- =============================================================================

SELECT
    r.r_name                                                 AS region_name,
    ROUND(SUM(l.l_extendedprice * (1 - l.l_discount)), 2)    AS receita_liquida_1995_automobile,
    COUNT(*)                                                 AS qtd_itens,
    COUNT(DISTINCT o.o_custkey)                              AS qtd_clientes_distintos
FROM oltp_mirror.lineitem l
JOIN oltp_mirror.orders   o ON o.o_orderkey = l.l_orderkey
JOIN oltp_mirror.customer c ON c.c_custkey  = o.o_custkey
JOIN oltp_mirror.nation   n ON n.n_nationkey = c.c_nationkey
JOIN oltp_mirror.region   r ON r.r_regionkey = n.n_regionkey
WHERE o.o_orderdate >= DATE '1995-01-01'
  AND o.o_orderdate <  DATE '1996-01-01'
  AND c.c_mktsegment = 'AUTOMOBILE'
GROUP BY r.r_name
ORDER BY receita_liquida_1995_automobile DESC;

-- -----------------------------------------------------------------------------
-- BÔNUS: inspecione o plano de execução
-- -----------------------------------------------------------------------------
-- Descomente para ver como o Redshift está resolvendo os joins:
--
-- EXPLAIN
-- SELECT r.r_name, SUM(l.l_extendedprice * (1 - l.l_discount))
-- FROM oltp_mirror.lineitem l
-- JOIN oltp_mirror.orders   o ON o.o_orderkey = l.l_orderkey
-- JOIN oltp_mirror.customer c ON c.c_custkey  = o.o_custkey
-- JOIN oltp_mirror.nation   n ON n.n_nationkey = c.c_nationkey
-- JOIN oltp_mirror.region   r ON r.r_regionkey = n.n_regionkey
-- WHERE o.o_orderdate >= DATE '1995-01-01'
--   AND o.o_orderdate <  DATE '1996-01-01'
--   AND c.c_mktsegment = 'AUTOMOBILE'
-- GROUP BY r.r_name;

-- =============================================================================
-- >>> ANOTE O RESULTADO como N1. Você vai comparar com N2 (dw_star) e N3 (dw_star_scd2).
-- =============================================================================
