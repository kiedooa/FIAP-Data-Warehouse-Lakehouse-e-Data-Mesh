-- =============================================================================
-- Lab 03.2 — Evolução 2 (Cliente ativo)
-- Arquivo: 03_tradeoffs.sql
-- Objetivo: queries que mostram onde as duas abordagens brilham ou sofrem.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- PERGUNTA 1: "Quantos clientes ativos em 1996-06-01?"
-- -----------------------------------------------------------------------------
-- Com SCD2 (Opção A):
SELECT
    'scd2' AS fonte,
    COUNT(*) AS qtd_ativos
FROM dw_star.dim_customer_v2
WHERE DATE '1996-06-01' BETWEEN valid_from AND valid_to
  AND is_active = TRUE;

-- Com snapshot mensal (Opção B):
SELECT
    'snapshot' AS fonte,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS qtd_ativos
FROM dw_star.f_customer_status_mensal
WHERE data_sk = 19960601;

-- COMENTÁRIO:
-- As duas DEVEM retornar o mesmo número (dentro de diferenças de lógica de borda).
-- O snapshot tende a ser MUITO mais rápido — é uma agregação numa tabela
-- já pré-calculada com sort em data_sk.

-- -----------------------------------------------------------------------------
-- PERGUNTA 2: "Evolução mensal de ativos nos últimos 3 anos"
-- -----------------------------------------------------------------------------
-- Com snapshot (natural):
SELECT
    data_sk,
    SUM(CASE WHEN is_active THEN 1 ELSE 0 END) AS qtd_ativos
FROM dw_star.f_customer_status_mensal
WHERE data_sk BETWEEN 19960101 AND 19981231
GROUP BY data_sk
ORDER BY data_sk;

-- Com SCD2: precisa gerar uma série de datas e fazer BETWEEN em cada linha
-- (muito mais complexo, mais lento). Exemplo ilustrativo:
WITH datas_ref AS (
    SELECT DISTINCT DATE_TRUNC('month', dt_completa) :: DATE AS mes_ref
    FROM dw_star.dim_data
    WHERE dt_completa BETWEEN DATE '1996-01-01' AND DATE '1998-12-31'
)
SELECT
    d.mes_ref,
    COUNT(*) AS qtd_ativos
FROM datas_ref d
JOIN dw_star.dim_customer_v2 cv
  ON d.mes_ref BETWEEN cv.valid_from AND cv.valid_to
 AND cv.is_active = TRUE
GROUP BY d.mes_ref
ORDER BY d.mes_ref;

-- -----------------------------------------------------------------------------
-- PERGUNTA 3: "Quem eram os clientes ativos AUTOMOBILE em cada mês de 1997?"
-- -----------------------------------------------------------------------------
-- Este é o caso em que o SCD2 BRILHA — queremos o status + segmento + histórico
-- na mesma tabela.
--
-- Com SCD2:
SELECT
    DATE_TRUNC('month', f.dt_envio) :: DATE AS mes,
    COUNT(DISTINCT cv.c_custkey)            AS qtd_ativos_automobile
FROM dw_star.f_vendas f
JOIN dw_star.dim_customer_v2 cv
  ON cv.c_custkey   = (SELECT c_custkey FROM dw_star.dim_customer WHERE customer_sk = f.customer_sk)
 AND f.dt_envio BETWEEN cv.valid_from AND cv.valid_to
WHERE cv.is_active   = TRUE
  AND cv.sg_segmento = 'AUTOMOBILE'
  AND f.dt_envio BETWEEN DATE '1997-01-01' AND DATE '1997-12-31'
GROUP BY DATE_TRUNC('month', f.dt_envio)
ORDER BY mes;

-- Com snapshot: precisa juntar snapshot + dim_customer para pegar segmento.
-- Funciona, mas o cross-join SCD2 + fato é mais natural para queries deste tipo.

-- -----------------------------------------------------------------------------
-- PERGUNTA 4: "Quantos clientes foram ativos por pelo menos 24 meses no total?"
-- -----------------------------------------------------------------------------
-- Com snapshot (trivial):
SELECT COUNT(*) AS clientes_ativos_24m_ou_mais
FROM (
    SELECT customer_sk
    FROM dw_star.f_customer_status_mensal
    WHERE is_active
    GROUP BY customer_sk
    HAVING COUNT(*) >= 24
) t;

-- Com SCD2: exige desenrolar o intervalo em meses — mais custo, mais SQL.
-- É viável mas não é elegante. Se a pergunta for recorrente, justifica ter a fato snapshot.

-- =============================================================================
-- CONCLUSÃO ANALÍTICA (para o aluno discutir):
--
--   * SCD2 ganha quando a pergunta é sobre "ESTADO DE UM CLIENTE NUM INSTANTE"
--     (ex: filtrar vendas pelo segmento vigente na data).
--
--   * Snapshot ganha quando a pergunta é sobre "CONTAGEM/AGREGAÇÃO DE ESTADOS
--     AO LONGO DO TEMPO" (ex: quantos ativos por mês, tendência de churn).
--
--   * Em muitos warehouses produtivos você tem AMBAS — a SCD2 para queries
--     transacionais e a snapshot para os dashboards temporais.
--
--   * Custo: SCD2 é mais compacta (só registra transições), snapshot é mais
--     "materializada" (todas as combinações mês × cliente).
-- =============================================================================
