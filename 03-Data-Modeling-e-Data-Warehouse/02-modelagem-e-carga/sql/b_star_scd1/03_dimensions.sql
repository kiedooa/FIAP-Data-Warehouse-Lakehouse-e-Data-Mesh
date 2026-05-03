-- =============================================================================
-- Lab 03.1 — Modelagem B (Star SCD1)
-- Arquivo: 03_dimensions.sql
-- Objetivo: criar e popular as demais dimensões a partir de oltp_mirror.*
-- =============================================================================
--
-- Assumimos que oltp_mirror já está carregado (Modelagem A executada).
-- Se não estiver, rode antes: sql/a_oltp_mirror/01_create_schema.sql + 02_copy_tables.sql
-- =============================================================================

-- =============================================================================
-- DIM_GEOGRAFIA — achata nation + region (star, não snowflake)
-- =============================================================================
CREATE TABLE dw_star.dim_geografia (
    geografia_sk  INTEGER     NOT NULL,   -- surrogate
    n_nationkey   INTEGER     NOT NULL,   -- natural key (preservada p/ debugging)
    nm_nacao      VARCHAR(25) NOT NULL,
    nm_regiao     VARCHAR(25) NOT NULL
)
DISTSTYLE ALL     -- pequena (25 linhas), replica em todos
SORTKEY (nm_regiao);

INSERT INTO dw_star.dim_geografia (geografia_sk, n_nationkey, nm_nacao, nm_regiao)
SELECT
    n.n_nationkey AS geografia_sk,   -- 1:1 com n_nationkey, não precisa gerar novo SK
    n.n_nationkey,
    n.n_name      AS nm_nacao,
    r.r_name      AS nm_regiao
FROM oltp_mirror.nation n
JOIN oltp_mirror.region r ON r.r_regionkey = n.n_regionkey;

ANALYZE dw_star.dim_geografia;

-- =============================================================================
-- DIM_CUSTOMER — SCD Tipo 1 (sobrescreve)
-- Uma linha por cliente; atributos refletem o ESTADO ATUAL da base.
-- =============================================================================
CREATE TABLE dw_star.dim_customer (
    customer_sk  BIGINT        NOT NULL,    -- surrogate
    c_custkey    BIGINT        NOT NULL,    -- natural key
    nm_cliente   VARCHAR(25)   NOT NULL,
    sg_segmento  VARCHAR(10)   NOT NULL,
    vl_saldo     DECIMAL(15,2) NOT NULL,
    n_nationkey  INTEGER       NOT NULL     -- FK p/ dim_geografia
)
DISTKEY (customer_sk)
SORTKEY (sg_segmento);

INSERT INTO dw_star.dim_customer (customer_sk, c_custkey, nm_cliente, sg_segmento, vl_saldo, n_nationkey)
SELECT
    c.c_custkey                              AS customer_sk,  -- 1:1 com c_custkey (SCD1)
    c.c_custkey,
    c.c_name                                 AS nm_cliente,
    c.c_mktsegment                           AS sg_segmento,
    c.c_acctbal                              AS vl_saldo,
    c.c_nationkey
FROM oltp_mirror.customer c;

ANALYZE dw_star.dim_customer;

-- =============================================================================
-- DIM_PRODUTO — achata part (com info agregada de partsupp)
-- =============================================================================
CREATE TABLE dw_star.dim_produto (
    produto_sk       BIGINT        NOT NULL,
    p_partkey        BIGINT        NOT NULL,
    nm_produto       VARCHAR(55)   NOT NULL,
    nm_fabricante    VARCHAR(25)   NOT NULL,
    nm_marca         VARCHAR(10)   NOT NULL,
    ds_tipo          VARCHAR(25)   NOT NULL,
    nr_tamanho       INTEGER       NOT NULL,
    nm_container     VARCHAR(10)   NOT NULL,
    vl_preco_varejo  DECIMAL(15,2) NOT NULL
)
DISTKEY (produto_sk)
SORTKEY (nm_marca);

INSERT INTO dw_star.dim_produto
SELECT
    p.p_partkey AS produto_sk,
    p.p_partkey,
    p.p_name,
    p.p_mfgr,
    p.p_brand,
    p.p_type,
    p.p_size,
    p.p_container,
    p.p_retailprice
FROM oltp_mirror.part p;

ANALYZE dw_star.dim_produto;

-- =============================================================================
-- DIM_SUPPLIER
-- =============================================================================
CREATE TABLE dw_star.dim_supplier (
    supplier_sk   BIGINT        NOT NULL,
    s_suppkey     BIGINT        NOT NULL,
    nm_fornecedor VARCHAR(25)   NOT NULL,
    vl_saldo      DECIMAL(15,2) NOT NULL,
    n_nationkey   INTEGER       NOT NULL
)
DISTSTYLE ALL    -- só 10k linhas
SORTKEY (supplier_sk);

INSERT INTO dw_star.dim_supplier
SELECT
    s.s_suppkey,
    s.s_suppkey,
    s.s_name,
    s.s_acctbal,
    s.s_nationkey
FROM oltp_mirror.supplier s;

ANALYZE dw_star.dim_supplier;

-- -----------------------------------------------------------------------------
-- Sanity checks
-- -----------------------------------------------------------------------------
SELECT 'dim_geografia' AS dim, COUNT(*) AS linhas FROM dw_star.dim_geografia
UNION ALL
SELECT 'dim_customer',  COUNT(*) FROM dw_star.dim_customer
UNION ALL
SELECT 'dim_produto',   COUNT(*) FROM dw_star.dim_produto
UNION ALL
SELECT 'dim_supplier',  COUNT(*) FROM dw_star.dim_supplier
UNION ALL
SELECT 'dim_data',      COUNT(*) FROM dw_star.dim_data
ORDER BY dim;
