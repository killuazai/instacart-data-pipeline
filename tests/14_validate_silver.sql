-- saved-query name: 14_validate_silver
-- paste the approved Databricks SQL for this task below
-- validates row preservation, entity grains, relationships, and approved business rules

WITH bronze_counts AS (
  SELECT
    (SELECT COUNT(*) FROM workspace.default.aisles) AS aisles_rows,
    (SELECT COUNT(*) FROM workspace.default.departments) AS departments_rows,
    (SELECT COUNT(*) FROM workspace.default.products) AS products_rows,
    (SELECT COUNT(*) FROM workspace.default.orders) AS orders_rows,
    (
      (SELECT COUNT(*) FROM workspace.default.order_products_prior)
      + (SELECT COUNT(*) FROM workspace.default.order_products_train)
    ) AS order_product_rows
),
silver_counts AS (
  SELECT
    (SELECT COUNT(*) FROM workspace.default.aisles) AS aisles_rows,
    (SELECT COUNT(*) FROM workspace.default.departments) AS departments_rows,
    (SELECT COUNT(*) FROM workspace.default.products) AS products_rows,
    (SELECT COUNT(*) FROM workspace.default.orders) AS orders_rows,
    (SELECT COUNT(*) FROM workspace.default.order_products) AS order_product_rows
),
aisles_metrics AS (
  SELECT
    COUNT_IF(aisle_id IS NULL) AS null_keys,
    COUNT(*) - COUNT(DISTINCT aisle_id) AS duplicate_keys
  FROM workspace.default.aisles
),
departments_metrics AS (
  SELECT
    COUNT_IF(department_id IS NULL) AS null_keys,
    COUNT(*) - COUNT(DISTINCT department_id) AS duplicate_keys
  FROM workspace.default.departments
),
products_metrics AS (
  SELECT
    COUNT_IF(product_id IS NULL OR aisle_id IS NULL OR department_id IS NULL) AS null_keys,
    COUNT(*) - COUNT(DISTINCT product_id) AS duplicate_keys
  FROM workspace.default.products
),
orders_metrics AS (
  SELECT
    COUNT_IF(order_id IS NULL OR user_id IS NULL) AS null_keys,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_ids,
    COUNT(*) - COUNT(DISTINCT struct(user_id, order_number)) AS duplicate_user_order_numbers,
    COUNT_IF(order_number < 1) AS invalid_order_numbers,
    COUNT_IF(order_dow NOT BETWEEN 0 AND 6) AS invalid_order_dow,
    COUNT_IF(order_hour_of_day NOT BETWEEN 0 AND 23) AS invalid_order_hours,
    COUNT_IF(eval_set NOT IN ('prior', 'train', 'test')) AS invalid_eval_sets,
    COUNT_IF(order_number = 1 AND days_since_prior_order IS NOT NULL) AS first_orders_with_days,
    COUNT_IF(order_number > 1 AND days_since_prior_order IS NULL) AS later_orders_without_days
  FROM workspace.default.orders
),
order_products_metrics AS (
  SELECT
    COUNT_IF(order_id IS NULL OR product_id IS NULL OR add_to_cart_order IS NULL) AS null_keys,
    COUNT(*) - COUNT(DISTINCT struct(order_id, add_to_cart_order)) AS duplicate_grain,
    COUNT(*) - COUNT(DISTINCT struct(order_id, product_id)) AS duplicate_order_products,
    COUNT_IF(reordered NOT IN (0, 1)) AS invalid_reordered,
    COUNT_IF(add_to_cart_order < 1) AS invalid_cart_positions,
    COUNT_IF(eval_set NOT IN ('prior', 'train')) AS invalid_eval_sets
  FROM workspace.default.order_products
),
product_relationships AS (
  SELECT
    COUNT_IF(a.aisle_id IS NULL) AS missing_aisles,
    COUNT_IF(d.department_id IS NULL) AS missing_departments
  FROM workspace.default.products p
  LEFT JOIN workspace.default.aisles a
    ON p.aisle_id = a.aisle_id
  LEFT JOIN workspace.default.departments d
    ON p.department_id = d.department_id
),
order_product_relationships AS (
  SELECT
    COUNT_IF(o.order_id IS NULL) AS missing_orders,
    COUNT_IF(p.product_id IS NULL) AS missing_products,
    COUNT_IF(o.order_id IS NOT NULL AND op.eval_set <> o.eval_set) AS mismatched_eval_sets
  FROM workspace.default.order_products op
  LEFT JOIN workspace.default.orders o
    ON op.order_id = o.order_id
  LEFT JOIN workspace.default.products p
    ON op.product_id = p.product_id
)
SELECT
  s.aisles_rows,
  s.departments_rows,
  s.products_rows,
  s.orders_rows,
  s.order_product_rows,
  assert_true(
    b.aisles_rows = s.aisles_rows
      AND b.departments_rows = s.departments_rows
      AND b.products_rows = s.products_rows
      AND b.orders_rows = s.orders_rows
      AND b.order_product_rows = s.order_product_rows,
    'silver row counts must reconcile to bronze'
  ) AS row_preservation_check,
  assert_true(
    am.null_keys + dm.null_keys + pm.null_keys + om.null_keys + opm.null_keys = 0,
    'silver required keys must not be null'
  ) AS required_key_check,
  assert_true(
    am.duplicate_keys + dm.duplicate_keys + pm.duplicate_keys
      + om.duplicate_order_ids + om.duplicate_user_order_numbers = 0,
    'silver entity keys must be unique'
  ) AS entity_key_check,
  assert_true(opm.duplicate_grain = 0, 'silver order product grain must be unique') AS fact_grain_check,
  assert_true(
    opm.duplicate_order_products = 0,
    'silver order and product combinations must be unique'
  ) AS order_product_key_check,
  assert_true(
    pr.missing_aisles + pr.missing_departments = 0,
    'every silver product must match an aisle and department'
  ) AS product_relationship_check,
  assert_true(
    opr.missing_orders + opr.missing_products + opr.mismatched_eval_sets = 0,
    'every silver order product must match its order, product, and evaluation set'
  ) AS order_product_relationship_check,
  assert_true(
    opm.invalid_reordered + opm.invalid_cart_positions + opm.invalid_eval_sets = 0,
    'silver order product values are outside approved ranges'
  ) AS order_product_value_check,
  assert_true(
    om.invalid_order_numbers + om.invalid_order_dow + om.invalid_order_hours + om.invalid_eval_sets = 0,
    'silver order values are outside approved ranges'
  ) AS order_value_check,
  assert_true(
    om.first_orders_with_days + om.later_orders_without_days = 0,
    'days since prior order must be null exactly for first orders'
  ) AS days_since_prior_order_check
FROM bronze_counts b
CROSS JOIN silver_counts s
CROSS JOIN aisles_metrics am
CROSS JOIN departments_metrics dm
CROSS JOIN products_metrics pm
CROSS JOIN orders_metrics om
CROSS JOIN order_products_metrics opm
CROSS JOIN product_relationships pr
CROSS JOIN order_product_relationships opr;
