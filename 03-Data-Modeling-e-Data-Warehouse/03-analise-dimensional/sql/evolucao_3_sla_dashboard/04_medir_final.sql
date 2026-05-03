-- =============================================================================
-- Lab 03.2 — Evolução 3 (SLA de 5s no dashboard)
-- Arquivo: 04_medir_final.sql
-- Objetivo: medir as alternativas e decidir.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A) QUERY na fato NOVA (com DISTKEY data_sk + SORTKEY composta)
-- -----------------------------------------------------------------------------
-- Rode 3x e use a mediana.
SELECT
    d.nr_ano,
    d.nr_mes,
    g.nm_regiao,
    c.sg_segmento,
    SUM(f.vl_receita_liquida) AS receita
FROM dw_star.f_vendas      f
JOIN dw_star.dim_data      d ON d.data_sk      = f.data_sk
JOIN dw_star.dim_geografia g ON g.geografia_sk = f.geografia_sk
JOIN dw_star.dim_customer  c ON c.customer_sk  = f.customer_sk
GROUP BY d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento
ORDER BY d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento;

-- Plano de execução
EXPLAIN
SELECT d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento, SUM(f.vl_receita_liquida)
FROM dw_star.f_vendas      f
JOIN dw_star.dim_data      d ON d.data_sk      = f.data_sk
JOIN dw_star.dim_geografia g ON g.geografia_sk = f.geografia_sk
JOIN dw_star.dim_customer  c ON c.customer_sk  = f.customer_sk
GROUP BY d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento;

-- -----------------------------------------------------------------------------
-- B) QUERY contra a MATERIALIZED VIEW (pré-agregada)
-- -----------------------------------------------------------------------------
SELECT
    nr_ano,
    nr_mes,
    nm_regiao,
    sg_segmento,
    receita_liquida
FROM dw_star.mv_dashboard_executivo
ORDER BY nr_ano, nr_mes, nm_regiao, sg_segmento;

-- Plano de execução
EXPLAIN
SELECT nr_ano, nr_mes, nm_regiao, sg_segmento, receita_liquida
FROM dw_star.mv_dashboard_executivo;

-- -----------------------------------------------------------------------------
-- C) Comparação final — últimas execuções de ambas as queries
-- -----------------------------------------------------------------------------
SELECT
    CASE
        WHEN querytxt ILIKE '%mv_dashboard_executivo%' THEN 'MV pre-agregada'
        WHEN querytxt ILIKE '%dim_customer%' AND querytxt ILIKE '%dim_geografia%' THEN 'Fato com nova distkey'
        ELSE 'outra'
    END                                           AS estrategia,
    starttime,
    DATEDIFF(ms, starttime, endtime)              AS duracao_ms,
    SUBSTRING(querytxt, 1, 80)                    AS query_snippet
FROM stl_query
WHERE userid > 1
  AND starttime > DATEADD(hour, -1, GETDATE())
  AND querytxt NOT ILIKE '%EXPLAIN%'
  AND (
      querytxt ILIKE '%mv_dashboard_executivo%'
   OR (querytxt ILIKE '%dim_customer%' AND querytxt ILIKE '%dim_geografia%')
  )
ORDER BY starttime DESC
LIMIT 20;

-- =============================================================================
-- >>> DECISÃO:
--   * Qual estratégia atingiu o SLA de 5s?
--   * Qual é mais fácil de manter?
--   * Qual "polui" menos (afeta menos outras queries)?
--
-- Típicas conclusões:
--   - MV pré-agregada costuma ser a vencedora de longe (milésimos).
--   - Redesign de DISTKEY ajuda QUALQUER query que filtre por data, mas força
--     mudar o padrão de outras queries históricas.
--
-- O mundo real costuma combinar: DISTKEY sensata + MV para os top-5 dashboards.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- ROLLBACK opcional: voltar a fato original do Lab 03.1
-- -----------------------------------------------------------------------------
-- DROP TABLE dw_star.f_vendas;
-- ALTER TABLE dw_star.f_vendas_original RENAME TO f_vendas;
-- ANALYZE dw_star.f_vendas;
