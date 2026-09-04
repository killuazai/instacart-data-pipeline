-- Owner: Cath
-- Name: 20a - Gold Final Validation (Table-Level)
-- Purpose: Table-level validation - keys, row counts, referential integrity.
-- Grain: One validation summary row per Gold table.

WITH validation AS (

    SELECT
        'gold_dim_product' AS table_name,
        COUNT(*) AS row_count,
        (SELECT COUNT(*) FROM instacart_silver.products_clean) AS source_row_count,
        SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_key_rows,
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM gold_dim_product
            WHERE product_id IS NOT NULL GROUP BY product_id HAVING COUNT(*) > 1
        )) AS duplicate_keys,
        SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS required_field_issues,
        0 AS unmatched_fk_rows
    FROM gold_dim_product

    UNION ALL

    SELECT
        'gold_dim_order',
        COUNT(*),
        (SELECT COUNT(*) FROM instacart_silver.orders_clean),
        SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id FROM gold_dim_order
            WHERE order_id IS NOT NULL GROUP BY order_id HAVING COUNT(*) > 1
        )),
        SUM(CASE WHEN user_id IS NULL OR order_number IS NULL THEN 1 ELSE 0 END),
        0
    FROM gold_dim_order

    UNION ALL

    SELECT
        'gold_fact_order_product',
        COUNT(*),
        (SELECT COUNT(*) FROM instacart_silver.order_products_clean),
        SUM(CASE WHEN order_id IS NULL OR product_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id, product_id FROM gold_fact_order_product
            WHERE order_id IS NOT NULL AND product_id IS NOT NULL
            GROUP BY order_id, product_id HAVING COUNT(*) > 1
        )),
        0,
        -- Check referential integrity: fact → dimensions
        (SELECT COUNT(*) FROM gold_fact_order_product f
            LEFT JOIN gold_dim_order o ON f.order_id = o.order_id
            WHERE f.order_id IS NOT NULL AND o.order_id IS NULL)
         + (SELECT COUNT(*) FROM gold_fact_order_product f
            LEFT JOIN gold_dim_product p ON f.product_id = p.product_id
            WHERE f.product_id IS NOT NULL AND p.product_id IS NULL)
    FROM gold_fact_order_product

)
SELECT
    table_name,
    row_count,
    source_row_count,
    row_count - source_row_count AS row_difference,
    null_key_rows,
    duplicate_keys,
    required_field_issues,
    unmatched_fk_rows,
    CASE
        WHEN null_key_rows > 0 OR duplicate_keys > 0
          OR required_field_issues > 0 OR unmatched_fk_rows > 0
          OR row_count <> source_row_count
        THEN 'REVIEW'
        ELSE 'PASS'
    END AS status
FROM validation
ORDER BY table_name;