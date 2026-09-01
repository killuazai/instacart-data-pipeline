-- identifies the bronze table containing null identifiers or rescued data

SELECT
  'aisles' AS table_name,
  COUNT(*) AS row_count,
  COUNT_IF(aisle_id IS NULL) AS null_required_ids,
  COUNT_IF(_rescued_data IS NOT NULL) AS rescued_rows
FROM workspace.instacart_bronze.aisles

UNION ALL

SELECT
  'departments',
  COUNT(*),
  COUNT_IF(department_id IS NULL),
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
  COUNT_IF(_rescued_data IS NOT NULL)
FROM workspace.instacart_bronze.order_products_train

ORDER BY null_required_ids DESC, rescued_rows DESC;
