-- Owner: Ina
-- Name: 13 - Silver Order Products
-- Purpose: Union the Bronze order_products_prior and order_products_train tables into
--          one, drop rows whose order_id doesn't exist in Silver, cast reordered to boolean.
-- Grain: One row per product line in one order, uniquely identified by (order_id, product_id).

CREATE OR REPLACE TABLE order_products_clean AS
WITH order_products_combined AS (
    SELECT *, 'prior' AS source_file
    FROM instacart_bronze.order_products_prior
    UNION ALL
    SELECT *, 'train' AS source_file
    FROM instacart_bronze.order_products_train
)
SELECT
    op.order_id,
    op.product_id,
    op.add_to_cart_order,
    CAST(op.reordered AS BOOLEAN) AS reordered,
    op.source_file
FROM order_products_combined op
WHERE op.order_id IS NOT NULL
  AND op.product_id IS NOT NULL
  AND EXISTS (SELECT 1 FROM orders_clean o WHERE o.order_id = op.order_id);

DESCRIBE TABLE order_products_clean;

-- source_file breakdown (informational) - confirms the union looks right
SELECT source_file, COUNT(*) AS row_count
FROM order_products_clean
GROUP BY source_file;