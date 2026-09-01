-- TABLE: PRODUCTS_RAW - product catalog, landed as-is. aisle_id/department_id are FKs.
-- PURPOSE: Ingest products.csv into the Bronze layer. No transformations.

USE CATALOG workspace;
USE SCHEMA instacart_bronze;

CREATE OR REPLACE TABLE products_raw AS
SELECT * FROM read_files(
  '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/products.csv',
  format => 'csv', header => true, escape => '"',
  schema => 'product_id BIGINT, product_name STRING, aisle_id INT, department_id INT'
);

DESCRIBE TABLE products_raw;