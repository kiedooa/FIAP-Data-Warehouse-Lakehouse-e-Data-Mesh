-- =============================================================================
-- Lab 03.2 — Evolução 1 (Nova fórmula de receita)
-- Arquivo: 01_extend_dim_supplier.sql
-- Objetivo: acrescentar atributo pct_comissao em dim_supplier.
-- =============================================================================
--
-- REGRA DE NEGÓCIO: cada fornecedor paga um % de comissão ao marketplace.
-- Para este lab, a comissão é atribuída pseudo-aleatoriamente com base no
-- s_suppkey (reprodutível), variando de 3% a 12%. Em produção viria de uma
-- tabela cadastral ou de um arquivo do financeiro.
-- =============================================================================

ALTER TABLE dw_star.dim_supplier
    ADD COLUMN pct_comissao DECIMAL(5,4) NOT NULL DEFAULT 0.0;

-- Atribuição determinística: comissão varia de 3% a 12% por fornecedor
UPDATE dw_star.dim_supplier
SET pct_comissao = ROUND( (((s_suppkey % 10) + 3) * 1.0 / 100), 4 );

ANALYZE dw_star.dim_supplier;

-- -----------------------------------------------------------------------------
-- Distribuição da comissão — sanity check
-- -----------------------------------------------------------------------------
SELECT
    pct_comissao,
    COUNT(*) AS qtd_fornecedores
FROM dw_star.dim_supplier
GROUP BY pct_comissao
ORDER BY pct_comissao;
