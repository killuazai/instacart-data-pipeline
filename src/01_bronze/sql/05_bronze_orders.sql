-- saved-query name: 05_bronze_orders
-- paste the approved Databricks SQL for this task below
-- TABLE: ORDERS_RAW - 7 fields
-- PURPOSE: Ingest the raw orders.csv data into the Bronze layer using an explicit schema. No cleaning or transformations are applied.

USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS instacart_bronze;
USE SCHEMA instacart_bronze;

CREATE OR REPLACE TABLE orders_raw AS
SELECT * FROM read_files(
  '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/orders.csv',
  format => 'csv', header => true, escape => '"',
  schema => 'order_id INT, user_id INT, eval_set STRING, order_number INT, order_dow INT, order_hour_of_day INT, days_since_prior_order DOUBLE'
);

DESCRIBE TABLE orders_raw;

SELECT *
FROM orders_raw;
