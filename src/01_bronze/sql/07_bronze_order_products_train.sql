-- Owner: Nadine
-- Name: 07 - Bronze Order Products Train
-- Purpose: Load train order-product records into the Bronze Delta table using an explicit schema while retaining rescued data.
-- Grain: One row per product line in one train order, uniquely identified by (order_id, add_to_cart_order).

CREATE TABLE IF NOT EXISTS workspace.instacart_bronze.order_products_train (
  order_id INT,
  product_id INT,
  add_to_cart_order INT,
  reordered INT,
  _rescued_data STRING
)
USING DELTA
COMMENT 'bronze copy of the instacart train order products csv';

INSERT OVERWRITE TABLE workspace.instacart_bronze.order_products_train
SELECT
  order_id,
  product_id,
  add_to_cart_order,
  reordered,
  _rescued_data
FROM read_files(
  '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/order_products__train.csv',
  format => 'csv',
  header => true,
  schema => 'order_id INT, product_id INT, add_to_cart_order INT, reordered INT',
  rescuedDataColumn => '_rescued_data'
);