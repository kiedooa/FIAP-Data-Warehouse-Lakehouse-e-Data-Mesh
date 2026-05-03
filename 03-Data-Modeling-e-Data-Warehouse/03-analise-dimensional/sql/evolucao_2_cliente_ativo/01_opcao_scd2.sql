-- =============================================================================
-- Lab 03.2 — Evolução 2 (Cliente ativo)
-- Arquivo: 01_opcao_scd2.sql
-- Objetivo: modelar "is_active" como atributo versionado SCD2 de dim_customer.
-- =============================================================================
--
-- REGRA DE NEGÓCIO:
--   Cliente ativo = comprou nos últimos 12 meses E saldo > -5000 (sem dívida alta)
--
-- ABORDAGEM (Opção A):
--   Cada cliente pode alternar entre ativo/inativo ao longo do tempo.
--   Tratamos is_active como ATRIBUTO DIMENSIONAL versionado.
--
-- OBSERVAÇÃO:
--   Nesta opção, criamos uma NOVA dimensão dim_customer_v2 em vez de alterar a
--   existente, para que os dashboards antigos continuem funcionando.
-- =============================================================================

CREATE TABLE dw_star.dim_customer_v2 (
    customer_v2_sk   BIGINT        NOT NULL,   -- surrogate de VERSÃO
    c_custkey        BIGINT        NOT NULL,
    nm_cliente       VARCHAR(25)   NOT NULL,
    sg_segmento      VARCHAR(10)   NOT NULL,
    vl_saldo         DECIMAL(15,2) NOT NULL,
    n_nationkey      INTEGER       NOT NULL,
    is_active        BOOLEAN       NOT NULL,
    valid_from       DATE          NOT NULL,
    valid_to         DATE          NOT NULL,
    is_current       BOOLEAN       NOT NULL
)
DISTKEY (c_custkey)
SORTKEY (c_custkey, valid_from);

-- -----------------------------------------------------------------------------
-- Calcular as TRANSIÇÕES de atividade para cada cliente.
-- Definimos a data de cada transição: início de cada mês em que o status muda.
-- Para simplificar (didática), vamos gerar um snapshot mensal em memória e
-- colapsar em intervalos de atividade.
-- -----------------------------------------------------------------------------

-- Passo 1: status mensal de cada cliente (CTE intermediária)
-- "ativo no mes M" = comprou nos 12 meses anteriores E saldo > -5000
WITH meses AS (
    SELECT DISTINCT
        DATE_TRUNC('month', dt_completa) :: DATE AS mes_ref
    FROM dw_star.dim_data
    WHERE dt_completa BETWEEN DATE '1993-01-01' AND DATE '1998-12-31'
),
compras AS (
    SELECT
        f.customer_sk,
        c.c_custkey,
        DATE_TRUNC('month', d.dt_completa) :: DATE AS mes_compra
    FROM dw_star.f_vendas     f
    JOIN dw_star.dim_data     d ON d.data_sk     = f.data_sk
    JOIN dw_star.dim_customer c ON c.customer_sk = f.customer_sk
    GROUP BY f.customer_sk, c.c_custkey, DATE_TRUNC('month', d.dt_completa)
),
status_mensal AS (
    SELECT
        cust.c_custkey,
        m.mes_ref,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM compras cp
                WHERE cp.c_custkey = cust.c_custkey
                  AND cp.mes_compra >= DATEADD(month, -12, m.mes_ref)
                  AND cp.mes_compra <  m.mes_ref
            )
             AND cust.vl_saldo > -5000
            THEN TRUE ELSE FALSE
        END AS is_active
    FROM dw_star.dim_customer cust
    CROSS JOIN meses m
),
-- Passo 2: identificar os MARCOS de mudança (primeira linha de cada grupo)
marcos AS (
    SELECT
        c_custkey,
        mes_ref,
        is_active,
        LAG(is_active) OVER (PARTITION BY c_custkey ORDER BY mes_ref) AS prev_status
    FROM status_mensal
),
transicoes AS (
    SELECT c_custkey, mes_ref AS valid_from, is_active
    FROM marcos
    WHERE prev_status IS NULL OR prev_status <> is_active
),
-- Passo 3: fechar cada intervalo com o próximo valid_from - 1
intervalos AS (
    SELECT
        c_custkey,
        valid_from,
        COALESCE(
            DATEADD(day, -1,
                LEAD(valid_from) OVER (PARTITION BY c_custkey ORDER BY valid_from)
            ),
            DATE '9999-12-31'
        ) AS valid_to,
        is_active
    FROM transicoes
)
-- Inserção final
INSERT INTO dw_star.dim_customer_v2
SELECT
    ROW_NUMBER() OVER (ORDER BY i.c_custkey, i.valid_from)  AS customer_v2_sk,
    i.c_custkey,
    c.nm_cliente,
    c.sg_segmento,
    c.vl_saldo,
    c.n_nationkey,
    i.is_active,
    i.valid_from,
    i.valid_to,
    CASE WHEN i.valid_to = DATE '9999-12-31' THEN TRUE ELSE FALSE END AS is_current
FROM intervalos i
JOIN dw_star.dim_customer c ON c.c_custkey = i.c_custkey;

ANALYZE dw_star.dim_customer_v2;

-- -----------------------------------------------------------------------------
-- Sanity: cada cliente deve ter pelo menos uma linha atual
-- -----------------------------------------------------------------------------
SELECT
    COUNT(DISTINCT c_custkey)                      AS clientes_distintos,
    COUNT(*)                                       AS linhas,
    SUM(CASE WHEN is_current THEN 1 ELSE 0 END)    AS linhas_atuais
FROM dw_star.dim_customer_v2;

-- Pergunta analítica: quantos clientes estavam ativos em 1996-06-01?
SELECT
    COUNT(*) AS clientes_ativos_19960601
FROM dw_star.dim_customer_v2
WHERE DATE '1996-06-01' BETWEEN valid_from AND valid_to
  AND is_active = TRUE;
