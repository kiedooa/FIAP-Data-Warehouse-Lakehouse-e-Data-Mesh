-- =============================================================================
-- Lab 03.1 — Modelagem B
-- Arquivo: 02_dim_data.sql
-- Objetivo: criar dim_data gerada por SQL para os anos 1992-1998
-- =============================================================================
--
-- Por que gerar dim_data em vez de extrair de uma tabela de datas existente?
--   - O TPC-H não traz uma tabela de datas.
--   - Geração via SQL é determinística e reprodutível.
--   - Garante cobertura de TODO o período sem buracos.
-- =============================================================================

CREATE TABLE dw_star.dim_data (
    data_sk          INTEGER     NOT NULL PRIMARY KEY,    -- surrogate key (YYYYMMDD como int)
    dt_completa      DATE        NOT NULL,
    nr_ano           SMALLINT    NOT NULL,
    nr_trimestre     SMALLINT    NOT NULL,
    nr_mes           SMALLINT    NOT NULL,
    nm_mes           VARCHAR(15) NOT NULL,
    nr_dia           SMALLINT    NOT NULL,
    nr_dia_semana    SMALLINT    NOT NULL,
    nm_dia_semana    VARCHAR(15) NOT NULL,
    fl_fim_de_semana BOOLEAN     NOT NULL,
    nr_semana_ano    SMALLINT    NOT NULL,
    nm_ano_trimestre VARCHAR(10) NOT NULL
)
DISTSTYLE ALL     -- pequena e usada em TODO join de fato — replica em todos os nós/slices
SORTKEY (dt_completa);

-- -----------------------------------------------------------------------------
-- Populando dim_data — 1992-01-01 até 1998-12-31
-- Usamos a técnica "tally table" do Redshift: join entre uma sequência pequena
-- (systable) para gerar N linhas sem loop explícito.
-- -----------------------------------------------------------------------------
INSERT INTO dw_star.dim_data
WITH numeros AS (
    -- gera 0..2556 (cobre 7 anos = ~2557 dias) via cross join em uma pg_catalog pequena
    SELECT ROW_NUMBER() OVER () - 1 AS n
    FROM stl_plan_info
    LIMIT 2557
),
datas AS (
    SELECT DATEADD(day, n, DATE '1992-01-01') AS dt
    FROM numeros
)
SELECT
    CAST(TO_CHAR(dt, 'YYYYMMDD') AS INTEGER) AS data_sk,
    dt                                       AS dt_completa,
    EXTRACT(YEAR    FROM dt)                 AS nr_ano,
    EXTRACT(QUARTER FROM dt)                 AS nr_trimestre,
    EXTRACT(MONTH   FROM dt)                 AS nr_mes,
    TRIM(TO_CHAR(dt, 'Month'))               AS nm_mes,
    EXTRACT(DAY     FROM dt)                 AS nr_dia,
    EXTRACT(DOW     FROM dt)                 AS nr_dia_semana,
    TRIM(TO_CHAR(dt, 'Day'))                 AS nm_dia_semana,
    CASE WHEN EXTRACT(DOW FROM dt) IN (0,6) THEN TRUE ELSE FALSE END AS fl_fim_de_semana,
    EXTRACT(WEEK    FROM dt)                 AS nr_semana_ano,
    EXTRACT(YEAR FROM dt) || '-Q' || EXTRACT(QUARTER FROM dt) AS nm_ano_trimestre
FROM datas;

-- -----------------------------------------------------------------------------
-- Fallback: se stl_plan_info estiver vazia/insuficiente, descomente e use este bloco.
-- -----------------------------------------------------------------------------
-- TRUNCATE dw_star.dim_data;
-- INSERT INTO dw_star.dim_data
-- WITH RECURSIVE serie(dt) AS (
--     SELECT DATE '1992-01-01'
--     UNION ALL
--     SELECT dt + 1 FROM serie WHERE dt < DATE '1998-12-31'
-- )
-- SELECT
--     CAST(TO_CHAR(dt, 'YYYYMMDD') AS INTEGER),
--     dt,
--     EXTRACT(YEAR FROM dt),
--     EXTRACT(QUARTER FROM dt),
--     EXTRACT(MONTH FROM dt),
--     TRIM(TO_CHAR(dt, 'Month')),
--     EXTRACT(DAY FROM dt),
--     EXTRACT(DOW FROM dt),
--     TRIM(TO_CHAR(dt, 'Day')),
--     CASE WHEN EXTRACT(DOW FROM dt) IN (0,6) THEN TRUE ELSE FALSE END,
--     EXTRACT(WEEK FROM dt),
--     EXTRACT(YEAR FROM dt) || '-Q' || EXTRACT(QUARTER FROM dt)
-- FROM serie;

ANALYZE dw_star.dim_data;

-- -----------------------------------------------------------------------------
-- Verificação — esperado: 2557 linhas (1992-01-01 até 1998-12-31)
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*)             AS total_datas,
    MIN(dt_completa)     AS primeira_data,
    MAX(dt_completa)     AS ultima_data
FROM dw_star.dim_data;
