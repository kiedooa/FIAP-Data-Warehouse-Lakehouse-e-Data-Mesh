-- =============================================================================
-- Lab 03.1 — Modelagem B (Star SCD1)
-- Arquivo: 04_fact.sql
-- Objetivo: criar e carregar f_vendas — tabela fato transacional.
-- =============================================================================
--
-- GRAIN: uma linha = um l_linenumber de um l_orderkey
--        (mesmo grain da tabela lineitem do TPC-H)
-- =============================================================================

CREATE TABLE dw_star.f_vendas (
    -- Chaves de dimensão (surrogate keys)
    data_sk              INTEGER       NOT NULL,   -- FK -> dim_data (pela data do pedido)
    customer_sk          BIGINT        NOT NULL,   -- FK -> dim_customer
    produto_sk           BIGINT        NOT NULL,   -- FK -> dim_produto
    supplier_sk          BIGINT        NOT NULL,   -- FK -> dim_supplier
    geografia_sk         INTEGER       NOT NULL,   -- FK -> dim_geografia (do cliente)

    -- Degenerate dimensions (identificadores transacionais)
    nr_pedido            BIGINT        NOT NULL,   -- l_orderkey / o_orderkey
    nr_linha_pedido      INTEGER       NOT NULL,   -- l_linenumber

    -- Medidas brutas (aditivas)
    qt_vendida           DECIMAL(15,2) NOT NULL,   -- l_quantity
    vl_preco_estendido   DECIMAL(15,2) NOT NULL,   -- l_extendedprice

    -- Medidas brutas (cuidado: l_discount e l_tax são não-aditivas)
    vl_desconto_pct      DECIMAL(15,2) NOT NULL,   -- l_discount (0..1)
    vl_imposto_pct       DECIMAL(15,2) NOT NULL,   -- l_tax (0..1)

    -- Medidas DERIVADAS (materializadas para contratualizar a fórmula)
    vl_receita_bruta     DECIMAL(18,4) NOT NULL,   -- l_extendedprice
    vl_receita_liquida   DECIMAL(18,4) NOT NULL,   -- l_extendedprice * (1 - l_discount)
    vl_receita_final     DECIMAL(18,4) NOT NULL,   -- l_extendedprice * (1 - l_discount) * (1 + l_tax)

    -- Status do item
    fl_retornado         CHAR(1)       NOT NULL,   -- l_returnflag
    fl_status_linha      CHAR(1)       NOT NULL,   -- l_linestatus

    -- Auditoria (útil pra debug)
    dt_envio             DATE          NOT NULL,   -- l_shipdate
    dt_recebimento       DATE          NOT NULL    -- l_receiptdate
)
DISTKEY (customer_sk)   -- co-loca vendas do mesmo cliente no mesmo slice
SORTKEY (data_sk);      -- habilita zone map pruning em filtros por data/ano

-- -----------------------------------------------------------------------------
-- Carga da fato — join entre lineitem, orders e as dimensões para trocar
-- chaves naturais por surrogate keys.
-- -----------------------------------------------------------------------------
-- Tempo esperado: 1-2 min (6M linhas)
-- -----------------------------------------------------------------------------
INSERT INTO dw_star.f_vendas
SELECT
    -- data_sk via TO_CHAR (aproveita o formato YYYYMMDD da dim_data)
    CAST(TO_CHAR(o.o_orderdate, 'YYYYMMDD') AS INTEGER)   AS data_sk,
    c.customer_sk,
    pr.produto_sk,
    s.supplier_sk,
    g.geografia_sk,

    l.l_orderkey                                          AS nr_pedido,
    l.l_linenumber                                        AS nr_linha_pedido,

    l.l_quantity                                          AS qt_vendida,
    l.l_extendedprice                                     AS vl_preco_estendido,

    l.l_discount                                          AS vl_desconto_pct,
    l.l_tax                                               AS vl_imposto_pct,

    l.l_extendedprice                                     AS vl_receita_bruta,
    l.l_extendedprice * (1 - l.l_discount)                AS vl_receita_liquida,
    l.l_extendedprice * (1 - l.l_discount) * (1 + l.l_tax) AS vl_receita_final,

    l.l_returnflag                                        AS fl_retornado,
    l.l_linestatus                                        AS fl_status_linha,
    l.l_shipdate                                          AS dt_envio,
    l.l_receiptdate                                       AS dt_recebimento
FROM oltp_mirror.lineitem l
JOIN oltp_mirror.orders   o  ON o.o_orderkey   = l.l_orderkey
JOIN dw_star.dim_customer c  ON c.c_custkey    = o.o_custkey
JOIN dw_star.dim_produto  pr ON pr.p_partkey   = l.l_partkey
JOIN dw_star.dim_supplier s  ON s.s_suppkey    = l.l_suppkey
JOIN dw_star.dim_geografia g ON g.n_nationkey  = c.n_nationkey;

ANALYZE dw_star.f_vendas;

-- -----------------------------------------------------------------------------
-- Sanity checks
-- -----------------------------------------------------------------------------
SELECT
    'f_vendas'                    AS objeto,
    COUNT(*)                      AS linhas,
    MIN(dt_envio)                 AS primeiro_envio,
    MAX(dt_envio)                 AS ultimo_envio,
    ROUND(SUM(vl_receita_liquida)) AS receita_liquida_total
FROM dw_star.f_vendas;

-- Esperado: 6.001.215 linhas (mesmo grain do lineitem do TPC-H SF1)
