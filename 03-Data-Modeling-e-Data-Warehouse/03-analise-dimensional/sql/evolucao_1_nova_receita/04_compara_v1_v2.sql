-- =============================================================================
-- Lab 03.2 — Evolução 1 (Nova fórmula de receita)
-- Arquivo: 04_compara_v1_v2.sql
-- Objetivo: quantificar o impacto da nova fórmula em números históricos.
-- =============================================================================
--
-- Três leituras que ajudam a decidir "recalcular ou congelar":
--   1. Diferença agregada por ano
--   2. Diferença por região × ano
--   3. Performance: MV vs. view para a mesma consulta
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1) Diferença agregada por ano
-- -----------------------------------------------------------------------------
WITH v1_ano AS (
    SELECT d.nr_ano, SUM(v.vl_receita_liquida) AS receita_v1
    FROM dw_star.v_receita_liquida_v1 v
    JOIN dw_star.dim_data             d ON d.data_sk = v.data_sk
    GROUP BY d.nr_ano
),
v2_ano AS (
    SELECT d.nr_ano, SUM(v.vl_receita_liquida) AS receita_v2
    FROM dw_star.v_receita_liquida_v2 v
    JOIN dw_star.dim_data             d ON d.data_sk = v.data_sk
    GROUP BY d.nr_ano
)
SELECT
    v1.nr_ano,
    ROUND(v1.receita_v1, 2)                                 AS receita_v1,
    ROUND(v2.receita_v2, 2)                                 AS receita_v2,
    ROUND(v1.receita_v1 - v2.receita_v2, 2)                 AS diferenca_abs,
    ROUND((v1.receita_v1 - v2.receita_v2) / v1.receita_v1 * 100, 2) AS diferenca_pct
FROM v1_ano v1
JOIN v2_ano v2 ON v2.nr_ano = v1.nr_ano
ORDER BY v1.nr_ano;

-- -----------------------------------------------------------------------------
-- 2) Diferença por região × ano — ajuda a ver se o impacto é uniforme
-- -----------------------------------------------------------------------------
WITH v1_reg AS (
    SELECT d.nr_ano, g.nm_regiao, SUM(v.vl_receita_liquida) AS receita_v1
    FROM dw_star.v_receita_liquida_v1 v
    JOIN dw_star.dim_data             d ON d.data_sk      = v.data_sk
    JOIN dw_star.dim_geografia        g ON g.geografia_sk = v.geografia_sk
    GROUP BY d.nr_ano, g.nm_regiao
),
v2_reg AS (
    SELECT d.nr_ano, g.nm_regiao, SUM(v.vl_receita_liquida) AS receita_v2
    FROM dw_star.v_receita_liquida_v2 v
    JOIN dw_star.dim_data             d ON d.data_sk      = v.data_sk
    JOIN dw_star.dim_geografia        g ON g.geografia_sk = v.geografia_sk
    GROUP BY d.nr_ano, g.nm_regiao
)
SELECT
    v1.nr_ano,
    v1.nm_regiao,
    ROUND(v1.receita_v1, 2) AS receita_v1,
    ROUND(v2.receita_v2, 2) AS receita_v2,
    ROUND((v1.receita_v1 - v2.receita_v2) / v1.receita_v1 * 100, 2) AS diferenca_pct
FROM v1_reg v1
JOIN v2_reg v2
  ON v2.nr_ano   = v1.nr_ano
 AND v2.nm_regiao = v1.nm_regiao
ORDER BY v1.nr_ano, v1.nm_regiao;

-- -----------------------------------------------------------------------------
-- 3) Performance — mesma consulta via view vs. MV
-- Rode cada bloco algumas vezes e compare o "execution time" no Query Editor v2.
-- -----------------------------------------------------------------------------

-- A) Via view (sempre recalcula)
EXPLAIN
SELECT d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento, SUM(v.vl_receita_liquida)
FROM dw_star.v_receita_liquida_v2 v
JOIN dw_star.dim_data      d ON d.data_sk      = v.data_sk
JOIN dw_star.dim_geografia g ON g.geografia_sk = v.geografia_sk
JOIN dw_star.dim_customer  c ON c.customer_sk  = v.customer_sk
WHERE d.nr_ano = 1997
GROUP BY d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento;

-- B) Via MV (já pré-agregada)
EXPLAIN
SELECT nr_ano, nr_mes, nm_regiao, sg_segmento, SUM(vl_receita_v2)
FROM dw_star.mv_receita_liquida_v2_mensal
WHERE nr_ano = 1997
GROUP BY nr_ano, nr_mes, nm_regiao, sg_segmento;

-- =============================================================================
-- REFLEXÃO:
--   * A diferença por região é uniforme ou há região mais penalizada?
--   * O ganho da MV justifica o custo de manutenção?
--   * Se a comissão mudar no ano que vem, qual caminho é mais fácil de
--     refletir: recriar a MV ou reescrever a view v2?
-- =============================================================================
