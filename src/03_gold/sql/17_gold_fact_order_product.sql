-- Owner: Cath
-- Name: 17 - Gold Fact Order Product
-- Purpose: Build the fact table linking orders and products with behavioral metrics.
-- Grain: One row per product line in one order, uniquely identified by (order_id, product_id).

CREATE OR REPLACE TABLE gold_fact_order_product AS
SELECT
    op.order_id, -- connects to dim_order table
    op.product_id, -- connects to dim_product table
    op.add_to_cart_order,
    op.reordered
FROM instacart_silver.order_products_clean op;

DESCRIBE TABLE gold_fact_order_product;