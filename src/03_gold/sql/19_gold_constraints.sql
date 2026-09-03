-- Owner: Cath
-- Name: 19 - Gold Constraints
-- Purpose: Validate PK/FK constraints across all gold tables.
-- Grain: One validation summary row per constraint check.

WITH constraint_checks AS (

    -- Check 1: gold_dim_product PK uniqueness
    SELECT
        'PK: gold_dim_product.product_id' AS constraint_name,
        'Primary Key Uniqueness' AS constraint_type,
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM gold_dim_product
            WHERE product_id IS NOT NULL
            GROUP BY product_id HAVING COUNT(*) > 1
        )) AS violations

    UNION ALL

    -- Check 2: gold_dim_order PK uniqueness
    SELECT
        'PK: gold_dim_order.order_id',
        'Primary Key Uniqueness',
        (SELECT COUNT(*) FROM (
            SELECT order_id FROM gold_dim_order
            WHERE order_id IS NOT NULL
            GROUP BY order_id HAVING COUNT(*) > 1
        ))

    UNION ALL

    -- Check 3: gold_fact_order_product composite PK uniqueness
    SELECT
        'PK: gold_fact_order_product (order_id, product_id)',
        'Composite Key Uniqueness',
        (SELECT COUNT(*) FROM (
            SELECT order_id, product_id FROM gold_fact_order_product
            WHERE order_id IS NOT NULL AND product_id IS NOT NULL
            GROUP BY order_id, product_id HAVING COUNT(*) > 1
        ))

    UNION ALL

    -- Check 4: gold_dim_product PK null check
    SELECT
        'PK: gold_dim_product.product_id NOT NULL',
        'Primary Key Null Check',
        (SELECT COUNT(*) FROM gold_dim_product WHERE product_id IS NULL)

    UNION ALL

    -- Check 5: gold_dim_order PK null check
    SELECT
        'PK: gold_dim_order.order_id NOT NULL',
        'Primary Key Null Check',
        (SELECT COUNT(*) FROM gold_dim_order WHERE order_id IS NULL)

    UNION ALL

    -- Check 6: gold_fact_order_product composite PK null check
    SELECT
        'PK: gold_fact_order_product (order_id, product_id) NOT NULL',
        'Composite Key Null Check',
        (SELECT COUNT(*) FROM gold_fact_order_product
         WHERE order_id IS NULL OR product_id IS NULL)

    UNION ALL

    -- Check 7: FK gold_fact_order_product.order_id → gold_dim_order.order_id
    SELECT
        'FK: gold_fact_order_product.order_id → gold_dim_order.order_id',
        'Foreign Key Integrity',
        (SELECT COUNT(*) FROM gold_fact_order_product f
         LEFT JOIN gold_dim_order d ON f.order_id = d.order_id
         WHERE f.order_id IS NOT NULL AND d.order_id IS NULL)

    UNION ALL

    -- Check 8: FK gold_fact_order_product.product_id → gold_dim_product.product_id
    SELECT
        'FK: gold_fact_order_product.product_id → gold_dim_product.product_id',
        'Foreign Key Integrity',
        (SELECT COUNT(*) FROM gold_fact_order_product f
         LEFT JOIN gold_dim_product d ON f.product_id = d.product_id
         WHERE f.product_id IS NOT NULL AND d.product_id IS NULL)

)
SELECT
    constraint_name,
    constraint_type,
    violations,
    CASE WHEN violations = 0 THEN 'PASS' ELSE 'REVIEW' END AS status
FROM constraint_checks
ORDER BY constraint_type, constraint_name;