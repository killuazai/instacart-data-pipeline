-- saved-query name: 07_bronze_order_products_train
-- paste the approved Databricks SQL for this task below

-- ============================================================
-- 07 BRONZE - ORDER PRODUCTS TRAIN
-- Source: order_products_train.csv
-- Grain: One row = one product included in one order
-- Purpose: Preserve the original Instacart training order-product data
-- ============================================================

CREATE OR REPLACE TABLE workspace.instacart_bronze.order_products_train AS

SELECT
    order_id,
    product_id,
    add_to_cart_order,
    reordered

FROM read_files(
    '/Volumes/workspace/default/ftw-b12-de/shared/week06/instacart_csv/order_products__train.csv',
    format => 'csv',
    header => true,
    inferSchema => false
);
