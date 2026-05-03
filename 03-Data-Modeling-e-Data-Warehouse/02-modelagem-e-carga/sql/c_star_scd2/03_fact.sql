-- =============================================================================
-- Lab 03.1 — Modelagem C (Star SCD2)
-- Arquivo: 03_fact.sql
-- Objetivo: construir f_vendas apontando para a VERSÃO correta de dim_customer
-- =============================================================================
--
-- DIFERENÇA CRÍTICA em relação ao 04_fact.sql da Modelagem B:
--   O JOIN com dim_customer usa não só c_custkey mas TAMBÉM a faixa temporal:
--     c.c_custkey = o.o_custkey
--     o.o_orderdate BETWEEN c.valid_from AND c.valid_to
--
-- Isso garante que cada item de pedido seja atribuído à versão do cliente
-- que era verdadeira no momento do pedido.
-- =============================================================================

CREATE TABLE dw_star_scd2.f_vendas (
    data_sk              INTEGER       NOT NULL,
    customer_sk          BIGINT        NOT NULL,   -- VERSÃO do cliente (SCD2)
    produto_sk           BIGINT        NOT NULL,
    supplier_sk          BIGINT        NOT NULL,
    geografia_sk         INTEGER       NOT NULL,

    nr_pedido            BIGINT        NOT NULL,
    nr_linha_pedido      INTEGER       NOT NULL,

    qt_vendida           DECIMAL(15,2) NOT NULL,
    vl_preco_estendido   DECIMAL(15,2) NOT NULL,
    vl_desconto_pct      DECIMAL(15,2) NOT NULL,
    vl_imposto_pct       DECIMAL(15,2) NOT NULL,

    vl_receita_bruta     DECIMAL(18,4) NOT NULL,
    vl_receita_liquida   DECIMAL(18,4) NOT NULL,
    vl_receita_final     DECIMAL(18,4) NOT NULL,

    fl_retornado         CHAR(1)       NOT NULL,
    fl_status_linha      CHAR(1)       NOT NULL,
    dt_envio             DATE          NOT NULL,
    dt_recebimento       DATE          NOT NULL
)
DISTKEY (customer_sk)
SORTKEY (data_sk);

-- -----------------------------------------------------------------------------
-- Carga — tempo esperado: 2-3 min
-- O join com range temporal torna esta query mais cara que a da Modelagem B.
-- -----------------------------------------------------------------------------
INSERT INTO dw_star_scd2.f_vendas
SELECT
    CAST(TO_CHAR(o.o_orderdate, 'YYYYMMDD') AS INTEGER)   AS data_sk,
    c.customer_sk,                              -- VERSÃO SCD2 correspondente à data
    pr.produto_sk,
    s.supplier_sk,
    g.geografia_sk,

    l.l_orderkey,
    l.l_linenumber,

    l.l_quantity,
    l.l_extendedprice,
    l.l_discount,
    l.l_tax,

    l.l_extendedprice,
    l.l_extendedprice * (1 - l.l_discount),
    l.l_extendedprice * (1 - l.l_discount) * (1 + l.l_tax),

    l.l_returnflag,
    l.l_linestatus,
    l.l_shipdate,
    l.l_receiptdate
FROM oltp_mirror.lineitem l
JOIN oltp_mirror.orders    o  ON o.o_orderkey = l.l_orderkey
JOIN dw_star_scd2.dim_customer c
      ON c.c_custkey = o.o_custkey
     AND o.o_orderdate >= c.valid_from
     AND o.o_orderdate <= c.valid_to
JOIN dw_star.dim_produto   pr ON pr.p_partkey  = l.l_partkey
JOIN dw_star.dim_supplier  s  ON s.s_suppkey   = l.l_suppkey
JOIN dw_star.dim_geografia g  ON g.n_nationkey = c.n_nationkey;

ANALYZE dw_star_scd2.f_vendas;

-- -----------------------------------------------------------------------------
-- Sanity checks
-- -----------------------------------------------------------------------------
SELECT
    'f_vendas_scd2'                AS objeto,
    COUNT(*)                       AS linhas,
    MIN(dt_envio)                  AS primeiro_envio,
    MAX(dt_envio)                  AS ultimo_envio,
    ROUND(SUM(vl_receita_liquida)) AS receita_liquida_total
FROM dw_star_scd2.f_vendas;

-- Esperado: 6.001.215 linhas — mesmo grain que dw_star.f_vendas.
-- Se vier menos, algum pedido não encontrou versão vigente do cliente (bug no SCD2).
