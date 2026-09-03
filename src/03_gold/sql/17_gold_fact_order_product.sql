-- Owner: Cath
-- Name: 17_gold_fact_order_product.sql
-- Purpose: Build the fact table linking orders and products with behavioral metrics.
-- Grain: One row per product line in one order, uniquely identified by (order_id, product_id).

CREATE OR REPLACE TABLE gold_fact_order_product AS
SELECT
    op.order_id,
    op.product_id,
    op.add_to_cart_order,
    op.reordered,
    o.user_id,
    o.order_number,
    o.order_dow,
    o.order_hour_of_day,
    p.aisle_id,
    p.department_id
FROM instacart_silver.order_products_clean op
INNER JOIN instacart_silver.orders_clean o ON op.order_id = o.order_id
INNER JOIN instacart_silver.products_clean p ON op.product_id = p.product_id;

DESCRIBE TABLE gold_fact_order_product;