-- Owner: Nadine
-- Name: 08 - Bronze Validation
-- Purpose: Validate Bronze row counts, required identifiers, candidate keys, required fields, domain rules, and rescued data.
-- Grain: One validation summary row per Bronze table.

WITH validation AS (

  SELECT
    'aisles' AS table_name,
    COUNT(*) AS actual_rows,
    COUNT_IF(aisle_id IS NULL) AS null_required_ids,
    COUNT(aisle_id) - COUNT(DISTINCT aisle_id)
      AS duplicate_primary_keys,
    CAST(0 AS BIGINT) AS duplicate_alternate_keys,
    COUNT_IF(
      aisle IS NULL
      OR TRIM(aisle) = ''
    ) AS required_field_issues,
    CAST(0 AS BIGINT) AS domain_issues,
    COUNT_IF(_rescued_data IS NOT NULL) AS rescued_rows
  FROM workspace.instacart_bronze.aisles

  UNION ALL

  SELECT
    'departments',
    COUNT(*),
    COUNT_IF(department_id IS NULL),
    COUNT(department_id) - COUNT(DISTINCT department_id),
    CAST(0 AS BIGINT),
    COUNT_IF(
      department IS NULL
      OR TRIM(department) = ''
    ),
    CAST(0 AS BIGINT),
    COUNT_IF(_rescued_data IS NOT NULL)
  FROM workspace.instacart_bronze.departments

  UNION ALL

  SELECT
    'products',
    COUNT(*),
    COUNT_IF(
      product_id IS NULL
      OR aisle_id IS NULL
      OR department_id IS NULL
    ),
    COUNT(product_id) - COUNT(DISTINCT product_id),
    CAST(0 AS BIGINT),
    COUNT_IF(
      product_name IS NULL
      OR TRIM(product_name) = ''
    ),
    CAST(0 AS BIGINT),
    COUNT_IF(_rescued_data IS NOT NULL)
  FROM workspace.instacart_bronze.products

  UNION ALL

  SELECT
    'orders',
    COUNT(*),
    COUNT_IF(
      order_id IS NULL
      OR user_id IS NULL
    ),
    COUNT(order_id) - COUNT(DISTINCT order_id),
    COUNT_IF(
      user_id IS NOT NULL
      AND order_number IS NOT NULL
    ) - COUNT(
      DISTINCT CASE
        WHEN user_id IS NOT NULL
          AND order_number IS NOT NULL
        THEN STRUCT(user_id, order_number)
      END
    ),
    COUNT_IF(
      eval_set IS NULL
      OR TRIM(eval_set) = ''
      OR order_number IS NULL
      OR order_dow IS NULL
      OR order_hour_of_day IS NULL
    ),
    COUNT_IF(
      eval_set NOT IN ('prior', 'train', 'test')
      OR order_number < 1
      OR order_dow NOT BETWEEN 0 AND 6
      OR order_hour_of_day NOT BETWEEN 0 AND 23
      OR days_since_prior_order < 0
      OR (
        order_number = 1
        AND days_since_prior_order IS NOT NULL
      )
      OR (
        order_number > 1
        AND days_since_prior_order IS NULL
      )
    ),
    COUNT_IF(_rescued_data IS NOT NULL)
  FROM workspace.instacart_bronze.orders

  UNION ALL

  SELECT
    'order_products_prior',
    COUNT(*),
    COUNT_IF(
      order_id IS NULL
      OR product_id IS NULL
      OR add_to_cart_order IS NULL
    ),
    COUNT_IF(
      order_id IS NOT NULL
      AND add_to_cart_order IS NOT NULL
    ) - COUNT(
      DISTINCT CASE
        WHEN order_id IS NOT NULL
          AND add_to_cart_order IS NOT NULL
        THEN STRUCT(order_id, add_to_cart_order)
      END
    ),
    COUNT_IF(
      order_id IS NOT NULL
      AND product_id IS NOT NULL
    ) - COUNT(
      DISTINCT CASE
        WHEN order_id IS NOT NULL
          AND product_id IS NOT NULL
        THEN STRUCT(order_id, product_id)
      END
    ),
    CAST(0 AS BIGINT),
    COUNT_IF(
      add_to_cart_order < 1
      OR reordered IS NULL
      OR reordered NOT IN (0, 1)
    ),
    COUNT_IF(_rescued_data IS NOT NULL)
  FROM workspace.instacart_bronze.order_products_prior

  UNION ALL

  SELECT
    'order_products_train',
    COUNT(*),
    COUNT_IF(
      order_id IS NULL
      OR product_id IS NULL
      OR add_to_cart_order IS NULL
    ),
    COUNT_IF(
      order_id IS NOT NULL
      AND add_to_cart_order IS NOT NULL
    ) - COUNT(
      DISTINCT CASE
        WHEN order_id IS NOT NULL
          AND add_to_cart_order IS NOT NULL
        THEN STRUCT(order_id, add_to_cart_order)
      END
    ),
    COUNT_IF(
      order_id IS NOT NULL
      AND product_id IS NOT NULL
    ) - COUNT(
      DISTINCT CASE
        WHEN order_id IS NOT NULL
          AND product_id IS NOT NULL
        THEN STRUCT(order_id, product_id)
      END
    ),
    CAST(0 AS BIGINT),
    COUNT_IF(
      add_to_cart_order < 1
      OR reordered IS NULL
      OR reordered NOT IN (0, 1)
    ),
    COUNT_IF(_rescued_data IS NOT NULL)
  FROM workspace.instacart_bronze.order_products_train

),

results AS (

  SELECT
    table_name,
    actual_rows,
    null_required_ids,
    duplicate_primary_keys,
    duplicate_alternate_keys,
    required_field_issues,
    domain_issues,
    rescued_rows,
    CASE
      WHEN actual_rows > 0
        AND null_required_ids = 0
        AND duplicate_primary_keys = 0
        AND duplicate_alternate_keys = 0
        AND required_field_issues = 0
        AND domain_issues = 0
        AND rescued_rows = 0
      THEN 'PASS'
      ELSE 'FAIL'
    END AS status
  FROM validation

)

SELECT
  table_name,
  actual_rows,
  null_required_ids,
  duplicate_primary_keys,
  duplicate_alternate_keys,
  required_field_issues,
  domain_issues,
  rescued_rows,
  status,
  assert_true(
    SUM(
      CASE
        WHEN status = 'FAIL' THEN 1
        ELSE 0
      END
    ) OVER () = 0,
    'one or more bronze tables failed validation; review the table-level metrics'
  ) AS bronze_validation_check
FROM results
ORDER BY table_name;