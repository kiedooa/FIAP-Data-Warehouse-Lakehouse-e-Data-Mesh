-- =============================================================================
-- Lab 03.2 — Evolução 3 (SLA de 5s no dashboard)
-- Arquivo: 01_medir_baseline.sql
-- Objetivo: medir a query "alvo" no estado atual antes de qualquer mudança.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- QUERY-ALVO do dashboard executivo — rode e note o tempo.
-- -----------------------------------------------------------------------------
-- Recomendado: rode 3 vezes e use a mediana (primeira execução costuma ser mais
-- lenta por causa de compilação e cache frio).
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- EXPLAIN — ler o plano antes do ANALYZE custoso
-- -----------------------------------------------------------------------------
EXPLAIN
SELECT
    d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento, SUM(f.vl_receita_liquida)
FROM dw_star.f_vendas      f
JOIN dw_star.dim_data      d ON d.data_sk      = f.data_sk
JOIN dw_star.dim_geografia g ON g.geografia_sk = f.geografia_sk
JOIN dw_star.dim_customer  c ON c.customer_sk  = f.customer_sk
GROUP BY d.nr_ano, d.nr_mes, g.nm_regiao, c.sg_segmento;

-- LER NO PLANO:
--   * Existe "DS_DIST_KEY" ou "DS_BCAST_INNER"? Isso indica redistribuição.
--   * A tabela grande (f_vendas) está sendo redistribuída? Redistribuição
--     de tabela grande é o primeiro suspeito quando a query está lenta.
--   * "XN Seq Scan" em f_vendas varre tudo? Sort key pode reduzir isso.

-- -----------------------------------------------------------------------------
-- Tempo recente das últimas 10 execuções desta query
-- -----------------------------------------------------------------------------
-- Identifique as queries pelo usuário e query text parcial:
SELECT
    query,
    starttime,
    endtime,
    DATEDIFF(ms, starttime, endtime) AS duracao_ms,
    SUBSTRING(querytxt, 1, 80)       AS query_snippet
FROM stl_query
WHERE userid > 1
  AND querytxt ILIKE '%dim_geografia%'
  AND querytxt ILIKE '%dim_customer%'
  AND querytxt NOT ILIKE '%EXPLAIN%'
ORDER BY starttime DESC
LIMIT 10;

-- =============================================================================
-- >>> ANOTE: tempo mediano do baseline = ____ ms
-- =============================================================================
