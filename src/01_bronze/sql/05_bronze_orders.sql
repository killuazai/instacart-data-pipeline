-- Owner: Nadine
-- Name: 05 - Bronze Orders
-- Purpose: Load Instacart order records into the Bronze Delta table using an explicit schema while retaining rescued data.
-- Grain: One row per Instacart order, uniquely identified by order_id.

CREATE TABLE IF NOT EXISTS workspace.instacart_bronze.orders (
  order_id INT,
  user_id INT,
  eval_set STRING,
  order_number INT,
  order_dow INT,
  order_hour_of_day INT,
  days_since_prior_order DOUBLE,
  _rescued_data STRING
)
USING DELTA
COMMENT 'bronze copy of the instacart orders csv';

INSERT OVERWRITE TABLE workspace.instacart_bronze.orders
SELECT
  order_id,
  user_id,
  eval_set,
  order_number,
  order_dow,
  order_hour_of_day,
  days_since_prior_order,
  _rescued_data
FROM read_files(
  '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/orders.csv',
  format => 'csv',
  header => true,
  schema => 'order_id INT, user_id INT, eval_set STRING, order_number INT, order_dow INT, order_hour_of_day INT, days_since_prior_order DOUBLE',
  rescuedDataColumn => '_rescued_data'
);