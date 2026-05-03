-- =============================================================================
-- Lab 03.1 — Modelagem B (Star Schema com SCD Tipo 1)
-- Arquivo: 01_create_schema.sql
-- Objetivo: criar schema dw_star para a modelagem dimensional clássica.
-- =============================================================================

DROP SCHEMA IF EXISTS dw_star CASCADE;
CREATE SCHEMA dw_star;

-- =============================================================================
-- GRAIN DA FATO (contrato):
--   "Uma linha de dw_star.f_vendas representa
--    um item (l_linenumber) de um pedido (o_orderkey),
--    vendido em uma data (data do pedido),
--    para um cliente (customer_sk),
--    de um produto (produto_sk),
--    fornecido por um fornecedor (supplier_sk)."
-- =============================================================================
