-- Owner: Cath
-- Name: 18_validate_gold_pre_constraints.sql
-- Purpose: Validate dimension tables before building the fact table.
-- Grain: One validation summary row per dimension table.

WITH validation AS (

    SELECT
        'gold_dim_product' AS table_name,
        COUNT(*) AS row_count,
        SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_key_rows,
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM gold_dim_product
            WHERE product_id IS NOT NULL GROUP BY product_id HAVING COUNT(*) > 1
        )) AS duplicate_keys,
        SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS required_field_issues
    FROM gold_dim_product

    UNION ALL

    SELECT
        'gold_dim_order',
        COUNT(*),
        SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id FROM gold_dim_order
            WHERE order_id IS NOT NULL GROUP BY order_id HAVING COUNT(*) > 1
        )),
        SUM(CASE WHEN user_id IS NULL OR order_number IS NULL THEN 1 ELSE 0 END)
    FROM gold_dim_order

)
SELECT
    table_name,
    row_count,
    null_key_rows,
    duplicate_keys,
    required_field_issues,
    CASE
        WHEN null_key_rows > 0 OR duplicate_keys > 0 OR required_field_issues > 0
        THEN 'REVIEW'
        ELSE 'PASS'
    END AS status
FROM validation
ORDER BY table_name;