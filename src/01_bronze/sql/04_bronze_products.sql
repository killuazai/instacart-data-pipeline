-- Owner: Nadine
-- Name: 04 - Bronze Products
-- Purpose: Load Instacart product records into the Bronze Delta table using an explicit schema and correct quotation-mark parsing while retaining rescued data.
-- Grain: One row per product, uniquely identified by product_id.

CREATE OR REPLACE TABLE workspace.instacart_bronze.products
USING DELTA
COMMENT 'bronze copy of the instacart products csv'
AS
SELECT
  product_id,
  product_name,
  aisle_id,
  department_id,
  _rescued_data
FROM read_files(
  '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/products.csv',
  format => 'csv',
  header => true,
  quote => '"',
  escape => '"',
  schema => 'product_id INT, product_name STRING, aisle_id INT, department_id INT',
  rescuedDataColumn => '_rescued_data'
);