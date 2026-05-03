-- =============================================================================
-- Lab 03.1 — Modelagem A (Espelho OLTP)
-- Arquivo: 01_create_schema.sql
-- Objetivo: criar schema e as 8 tabelas TPC-H como cópia fiel do modelo relacional
-- =============================================================================
--
-- IMPORTANTE: este schema NÃO é uma modelagem dimensional. É uma cópia do
-- modelo operacional (OLTP-style). Serve como baseline — a pergunta-âncora vai
-- rodar aqui e depois será comparada com os schemas dw_star e dw_star_scd2.
-- =============================================================================

DROP SCHEMA IF EXISTS oltp_mirror CASCADE;
CREATE SCHEMA oltp_mirror;

-- -----------------------------------------------------------------------------
-- Tabelas de referência (pequenas, estáveis) — DISTSTYLE ALL para replicar em
-- todos os slices e evitar redistribuição em joins.
-- -----------------------------------------------------------------------------
CREATE TABLE oltp_mirror.region (
    r_regionkey INTEGER     NOT NULL PRIMARY KEY,
    r_name      VARCHAR(25) NOT NULL,
    r_comment   VARCHAR(152)
)
DISTSTYLE ALL;

CREATE TABLE oltp_mirror.nation (
    n_nationkey INTEGER     NOT NULL PRIMARY KEY,
    n_name      VARCHAR(25) NOT NULL,
    n_regionkey INTEGER     NOT NULL,
    n_comment   VARCHAR(152)
)
DISTSTYLE ALL;

-- -----------------------------------------------------------------------------
-- Tabelas "mestre" — DISTSTYLE AUTO deixa o Redshift decidir.
-- -----------------------------------------------------------------------------
CREATE TABLE oltp_mirror.customer (
    c_custkey    BIGINT        NOT NULL PRIMARY KEY,
    c_name       VARCHAR(25)   NOT NULL,
    c_address    VARCHAR(40)   NOT NULL,
    c_nationkey  INTEGER       NOT NULL,
    c_phone      VARCHAR(15)   NOT NULL,
    c_acctbal    DECIMAL(15,2) NOT NULL,
    c_mktsegment VARCHAR(10)   NOT NULL,
    c_comment    VARCHAR(117)  NOT NULL
)
DISTSTYLE AUTO;

CREATE TABLE oltp_mirror.supplier (
    s_suppkey   BIGINT        NOT NULL PRIMARY KEY,
    s_name      VARCHAR(25)   NOT NULL,
    s_address   VARCHAR(40)   NOT NULL,
    s_nationkey INTEGER       NOT NULL,
    s_phone     VARCHAR(15)   NOT NULL,
    s_acctbal   DECIMAL(15,2) NOT NULL,
    s_comment   VARCHAR(101)  NOT NULL
)
DISTSTYLE AUTO;

CREATE TABLE oltp_mirror.part (
    p_partkey     BIGINT        NOT NULL PRIMARY KEY,
    p_name        VARCHAR(55)   NOT NULL,
    p_mfgr        VARCHAR(25)   NOT NULL,
    p_brand       VARCHAR(10)   NOT NULL,
    p_type        VARCHAR(25)   NOT NULL,
    p_size        INTEGER       NOT NULL,
    p_container   VARCHAR(10)   NOT NULL,
    p_retailprice DECIMAL(15,2) NOT NULL,
    p_comment     VARCHAR(23)   NOT NULL
)
DISTSTYLE AUTO;

CREATE TABLE oltp_mirror.partsupp (
    ps_partkey    BIGINT        NOT NULL,
    ps_suppkey    BIGINT        NOT NULL,
    ps_availqty   INTEGER       NOT NULL,
    ps_supplycost DECIMAL(15,2) NOT NULL,
    ps_comment    VARCHAR(199)  NOT NULL,
    PRIMARY KEY (ps_partkey, ps_suppkey)
)
DISTSTYLE AUTO;

-- -----------------------------------------------------------------------------
-- Tabelas transacionais — grandes, crescem com o tempo.
-- orders: DISTKEY em o_custkey ajuda joins com customer.
-- lineitem: DISTKEY em l_orderkey ajuda joins com orders (mesma chave de distribuição).
-- SORTKEY em data (o_orderdate / l_shipdate) habilita zone map pruning.
-- -----------------------------------------------------------------------------
CREATE TABLE oltp_mirror.orders (
    o_orderkey      BIGINT        NOT NULL PRIMARY KEY,
    o_custkey       BIGINT        NOT NULL,
    o_orderstatus   CHAR(1)       NOT NULL,
    o_totalprice    DECIMAL(15,2) NOT NULL,
    o_orderdate     DATE          NOT NULL,
    o_orderpriority VARCHAR(15)   NOT NULL,
    o_clerk         VARCHAR(15)   NOT NULL,
    o_shippriority  INTEGER       NOT NULL,
    o_comment       VARCHAR(79)   NOT NULL
)
DISTKEY (o_custkey)
SORTKEY (o_orderdate);

CREATE TABLE oltp_mirror.lineitem (
    l_orderkey      BIGINT        NOT NULL,
    l_partkey       BIGINT        NOT NULL,
    l_suppkey       BIGINT        NOT NULL,
    l_linenumber    INTEGER       NOT NULL,
    l_quantity      DECIMAL(15,2) NOT NULL,
    l_extendedprice DECIMAL(15,2) NOT NULL,
    l_discount      DECIMAL(15,2) NOT NULL,
    l_tax           DECIMAL(15,2) NOT NULL,
    l_returnflag    CHAR(1)       NOT NULL,
    l_linestatus    CHAR(1)       NOT NULL,
    l_shipdate      DATE          NOT NULL,
    l_commitdate    DATE          NOT NULL,
    l_receiptdate   DATE          NOT NULL,
    l_shipinstruct  VARCHAR(25)   NOT NULL,
    l_shipmode      VARCHAR(10)   NOT NULL,
    l_comment       VARCHAR(44)   NOT NULL,
    PRIMARY KEY (l_orderkey, l_linenumber)
)
DISTKEY (l_orderkey)
SORTKEY (l_shipdate);

-- -----------------------------------------------------------------------------
-- Verificação
-- -----------------------------------------------------------------------------
SELECT table_name, table_type
FROM information_schema.tables
WHERE table_schema = 'oltp_mirror'
ORDER BY table_name;
