-- =============================================================================
-- Lab 03.1 — Modelagem C (Star SCD2)
-- Arquivo: 02_dim_customer_scd2.sql
-- Objetivo: construir dim_customer versionada a partir de customer + customer_history
-- =============================================================================
--
-- REGRA DE NEGÓCIO:
--   - Cliente sem histórico: 1 linha, valid_from=1900-01-01, valid_to=9999-12-31
--   - Cliente com histórico: 2 linhas
--       * Versão original: segmento inicial, vale até valid_from_history - 1
--       * Versão atual:    mktsegment_new,   vale a partir de valid_from_history
--
-- OBSERVAÇÃO DIDÁTICA:
--   O TPC-H não armazena o "segmento original" — só o atual. A customer_history
--   gerada pelo script registra "como o cliente era ANTES" implicitamente:
--   a linha atual de oltp_mirror.customer representa o estado original
--   (antes da reclassificação de 1996+), e customer_history tem o novo segmento.
--   ATENÇÃO: isso é proposital. No TPC-H, o segmento em 1995 é o que está em
--   oltp_mirror.customer.c_mktsegment (original).
-- =============================================================================

CREATE TABLE dw_star_scd2.dim_customer (
    customer_sk       BIGINT        NOT NULL,   -- IDENTITY-like; diferencia VERSÕES
    c_custkey         BIGINT        NOT NULL,   -- chave natural (pode aparecer 2x)
    nm_cliente        VARCHAR(25)   NOT NULL,
    sg_segmento       VARCHAR(10)   NOT NULL,
    vl_saldo          DECIMAL(15,2) NOT NULL,
    n_nationkey       INTEGER       NOT NULL,

    -- Colunas de versionamento
    valid_from        DATE          NOT NULL,
    valid_to          DATE          NOT NULL,
    is_current        BOOLEAN       NOT NULL
)
DISTKEY (customer_sk)
SORTKEY (c_custkey, valid_from);

-- -----------------------------------------------------------------------------
-- Popular dim_customer em duas "ondas":
--   Onda 1: CLIENTES SEM RECLASSIFICAÇÃO — apenas 1 linha (versão eterna).
--   Onda 2: CLIENTES COM RECLASSIFICAÇÃO — 2 linhas (original + nova).
--
-- Para customer_sk geramos um bigint único combinando c_custkey * 10 + versao.
-- Versões: 1 = original, 2 = reclassificada.
-- -----------------------------------------------------------------------------

-- Onda 1: sem histórico
INSERT INTO dw_star_scd2.dim_customer
SELECT
    c.c_custkey * 10 + 1    AS customer_sk,   -- versão 1
    c.c_custkey,
    c.c_name                AS nm_cliente,
    c.c_mktsegment          AS sg_segmento,
    c.c_acctbal             AS vl_saldo,
    c.c_nationkey,
    DATE '1900-01-01'       AS valid_from,
    DATE '9999-12-31'       AS valid_to,
    TRUE                    AS is_current
FROM oltp_mirror.customer c
WHERE c.c_custkey NOT IN (SELECT c_custkey FROM dw_star_scd2.customer_history);

-- Onda 2 — parte A: versão ORIGINAL dos reclassificados
-- (vigente ANTES da mudança; segmento vem da tabela customer como estava originalmente)
INSERT INTO dw_star_scd2.dim_customer
SELECT
    c.c_custkey * 10 + 1           AS customer_sk,
    c.c_custkey,
    c.c_name                       AS nm_cliente,
    c.c_mktsegment                 AS sg_segmento,  -- segmento ORIGINAL
    c.c_acctbal                    AS vl_saldo,
    c.c_nationkey,
    DATE '1900-01-01'              AS valid_from,
    h.valid_from - INTERVAL '1 day' AS valid_to,
    FALSE                          AS is_current
FROM oltp_mirror.customer    c
JOIN dw_star_scd2.customer_history h ON h.c_custkey = c.c_custkey;

-- Onda 2 — parte B: versão NOVA dos reclassificados (vigente a partir de valid_from)
INSERT INTO dw_star_scd2.dim_customer
SELECT
    c.c_custkey * 10 + 2           AS customer_sk,  -- versão 2
    c.c_custkey,
    c.c_name                       AS nm_cliente,
    h.mktsegment_new               AS sg_segmento,  -- segmento NOVO
    c.c_acctbal                    AS vl_saldo,
    c.c_nationkey,
    h.valid_from                   AS valid_from,
    DATE '9999-12-31'              AS valid_to,
    TRUE                           AS is_current
FROM oltp_mirror.customer    c
JOIN dw_star_scd2.customer_history h ON h.c_custkey = c.c_custkey;

ANALYZE dw_star_scd2.dim_customer;

-- -----------------------------------------------------------------------------
-- Validações de integridade SCD2
-- -----------------------------------------------------------------------------
-- 1) Cada c_custkey deve ter PELO MENOS uma linha is_current=TRUE
SELECT
    'clientes_sem_versao_atual' AS check_name,
    COUNT(*) AS qtd
FROM oltp_mirror.customer c
WHERE NOT EXISTS (
    SELECT 1 FROM dw_star_scd2.dim_customer d
    WHERE d.c_custkey = c.c_custkey AND d.is_current = TRUE
);
-- Esperado: 0

-- 2) Nenhum intervalo [valid_from, valid_to] deve se sobrepor para o mesmo c_custkey
WITH pares AS (
    SELECT
        c_custkey,
        valid_from,
        valid_to,
        LAG(valid_to) OVER (PARTITION BY c_custkey ORDER BY valid_from) AS prev_valid_to
    FROM dw_star_scd2.dim_customer
)
SELECT
    'sobreposicoes_scd2' AS check_name,
    COUNT(*) AS qtd
FROM pares
WHERE prev_valid_to IS NOT NULL
  AND prev_valid_to >= valid_from;
-- Esperado: 0

-- 3) Distribuição de versões
SELECT
    COUNT(DISTINCT c_custkey)                                    AS clientes_distintos,
    COUNT(*)                                                     AS total_linhas,
    SUM(CASE WHEN is_current THEN 1 ELSE 0 END)                  AS linhas_atuais,
    SUM(CASE WHEN NOT is_current THEN 1 ELSE 0 END)              AS linhas_historicas
FROM dw_star_scd2.dim_customer;
-- Esperado: 150k clientes, ~157.5k linhas (150k atuais + 7.5k históricas)
