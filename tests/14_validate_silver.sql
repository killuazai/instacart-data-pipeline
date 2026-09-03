-- Owner: Ina
-- Name: 14 - Silver Validation
-- Purpose: Validate Silver row counts, required identifiers, candidate keys, required fields,
--          referential integrity, and text-quality artifacts with table-level pass or fail results.
-- Grain: One validation summary row per Silver table.

WITH validation AS (

    SELECT
        'aisles' AS table_name,
        (SELECT COUNT(*) FROM instacart_bronze.aisles) AS raw_rows,
        COUNT(*) AS clean_rows,
        COUNT(*) - (SELECT COUNT(*) FROM instacart_bronze.aisles) AS row_difference,
        SUM(CASE WHEN aisle_id IS NULL THEN 1 ELSE 0 END) AS null_key_rows,
        (SELECT COUNT(*) FROM (
            SELECT aisle_id FROM aisles_clean
            WHERE aisle_id IS NOT NULL GROUP BY aisle_id HAVING COUNT(*) > 1
        )) AS duplicate_keys,
        SUM(CASE WHEN aisle IS NULL OR TRIM(aisle) = '' THEN 1 ELSE 0 END) AS required_field_issues,
        0 AS unmatched_fk_rows
    FROM aisles_clean

    UNION ALL

    SELECT
        'departments',
        (SELECT COUNT(*) FROM instacart_bronze.departments),
        COUNT(*),
        COUNT(*) - (SELECT COUNT(*) FROM instacart_bronze.departments),
        SUM(CASE WHEN department_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT department_id FROM departments_clean
            WHERE department_id IS NOT NULL GROUP BY department_id HAVING COUNT(*) > 1
        )),
        SUM(CASE WHEN department IS NULL OR TRIM(department) = '' THEN 1 ELSE 0 END),
        0
    FROM departments_clean

    UNION ALL

    SELECT
        'products',
        (SELECT COUNT(*) FROM instacart_bronze.products),
        COUNT(*),
        COUNT(*) - (SELECT COUNT(*) FROM instacart_bronze.products),
        SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM products_clean
            WHERE product_id IS NOT NULL GROUP BY product_id HAVING COUNT(*) > 1
        )),
        SUM(CASE WHEN product_name IS NULL OR TRIM(product_name) = '' THEN 1 ELSE 0 END)
         + SUM(CASE WHEN INSTR(product_name, CHR(92)) > 0 THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM products_clean p
            LEFT JOIN aisles_clean a ON p.aisle_id = a.aisle_id
            WHERE p.aisle_id IS NOT NULL AND a.aisle_id IS NULL)
         + (SELECT COUNT(*) FROM products_clean p
            LEFT JOIN departments_clean d ON p.department_id = d.department_id
            WHERE p.department_id IS NOT NULL AND d.department_id IS NULL)
    FROM products_clean

    UNION ALL

    SELECT
        'orders',
        (SELECT COUNT(*) FROM instacart_bronze.orders),
        COUNT(*),
        COUNT(*) - (SELECT COUNT(*) FROM instacart_bronze.orders),
        SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id FROM orders_clean
            WHERE order_id IS NOT NULL GROUP BY order_id HAVING COUNT(*) > 1
        )),
        SUM(CASE
            WHEN user_id IS NULL
              OR order_number IS NULL
              OR order_dow NOT BETWEEN 0 AND 6
              OR order_hour_of_day NOT BETWEEN 0 AND 23
            
            -- First order should have no prior order interval
              OR (
                  order_number = 1
                  AND days_since_prior_order IS NOT NULL
              )

              -- Orders after the first should have a prior order interval
              OR (
                  order_number > 1
                  AND days_since_prior_order IS NULL
              )
            THEN 1
            ELSE 0
        END
    ),
    0
    FROM orders_clean

    UNION ALL

    SELECT
        'order_products',
        (SELECT COUNT(*) FROM instacart_bronze.order_products_prior)
          + (SELECT COUNT(*) FROM instacart_bronze.order_products_train),
        COUNT(*),
        COUNT(*) - (
            (SELECT COUNT(*) FROM instacart_bronze.order_products_prior)
          + (SELECT COUNT(*) FROM instacart_bronze.order_products_train)
        ),
        SUM(CASE WHEN order_id IS NULL OR product_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id, product_id FROM order_products_clean
            GROUP BY order_id, product_id HAVING COUNT(*) > 1
        )),
        SUM(CASE
            WHEN add_to_cart_order IS NULL OR add_to_cart_order <= 0
            THEN 1 ELSE 0
        END),
        (SELECT COUNT(*) FROM order_products_clean op
            LEFT JOIN orders_clean o ON op.order_id = o.order_id
            WHERE o.order_id IS NULL)
         + (SELECT COUNT(*) FROM order_products_clean op
            LEFT JOIN products_clean p ON op.product_id = p.product_id
            WHERE p.product_id IS NULL)
    FROM order_products_clean

)

SELECT
    *,
    CASE
        WHEN null_key_rows = 0
             AND duplicate_keys = 0
             AND required_field_issues = 0
             AND unmatched_fk_rows = 0
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS status
FROM validation
ORDER BY table_name;