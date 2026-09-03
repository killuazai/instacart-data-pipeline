-- Owner: Cath
-- Name: 20_validate_gold_final.sql
-- Purpose: Comprehensive gold validation - keys, integrity, silver-to-gold reconciliation, and measures.
-- Grain: Two result sets - (1) table-level validation, (2) measure reconciliation.

-- PART 1: Table-level validation (keys, row counts, referential integrity)
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

-- PART 2: Measure reconciliation (aggregate validation)
WITH silver_measures AS (
    SELECT
        COUNT(*) AS total_order_lines,
        COUNT(DISTINCT order_id) AS distinct_orders,
        COUNT(DISTINCT product_id) AS distinct_products,
        SUM(CASE WHEN reordered = TRUE THEN 1 ELSE 0 END) AS reordered_count,
        SUM(add_to_cart_order) AS total_cart_position_sum
    FROM instacart_silver.order_products_clean
),
gold_measures AS (
    SELECT
        COUNT(*) AS total_order_lines,
        COUNT(DISTINCT order_id) AS distinct_orders,
        COUNT(DISTINCT product_id) AS distinct_products,
        SUM(CASE WHEN reordered = TRUE THEN 1 ELSE 0 END) AS reordered_count,
        SUM(add_to_cart_order) AS total_cart_position_sum
    FROM gold_fact_order_product
)
SELECT
    'total_order_lines' AS measure,
    s.total_order_lines AS silver_value,
    g.total_order_lines AS gold_value,
    s.total_order_lines - g.total_order_lines AS difference,
    CASE WHEN s.total_order_lines = g.total_order_lines THEN 'PASS' ELSE 'REVIEW' END AS status
FROM silver_measures s, gold_measures g

UNION ALL

SELECT
    'distinct_orders',
    s.distinct_orders,
    g.distinct_orders,
    s.distinct_orders - g.distinct_orders,
    CASE WHEN s.distinct_orders = g.distinct_orders THEN 'PASS' ELSE 'REVIEW' END
FROM silver_measures s, gold_measures g

UNION ALL

SELECT
    'distinct_products',
    s.distinct_products,
    g.distinct_products,
    s.distinct_products - g.distinct_products,
    CASE WHEN s.distinct_products = g.distinct_products THEN 'PASS' ELSE 'REVIEW' END
FROM silver_measures s, gold_measures g

UNION ALL

SELECT
    'reordered_count',
    s.reordered_count,
    g.reordered_count,
    s.reordered_count - g.reordered_count,
    CASE WHEN s.reordered_count = g.reordered_count THEN 'PASS' ELSE 'REVIEW' END
FROM silver_measures s, gold_measures g

UNION ALL

SELECT
    'total_cart_position_sum',
    s.total_cart_position_sum,
    g.total_cart_position_sum,
    s.total_cart_position_sum - g.total_cart_position_sum,
    CASE WHEN s.total_cart_position_sum = g.total_cart_position_sum THEN 'PASS' ELSE 'REVIEW' END
FROM silver_measures s, gold_measures g;