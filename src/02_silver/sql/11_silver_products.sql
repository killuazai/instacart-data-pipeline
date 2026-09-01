-- TABLE: PRODUCTS_CLEAN - products, trimmed names, orphan aisle/department FKs dropped.
-- PURPOSE: Build the Silver-layer version of Products from instacart_bronze.
-- DEPENDS ON: 01_silver_aisles.sql, 02_silver_departments.sql (must run first).

USE CATALOG workspace;
USE SCHEMA instacart_silver;

CREATE OR REPLACE TABLE products_clean AS
SELECT
    p.product_id,
    TRIM(p.product_name) AS product_name,
    p.aisle_id,
    p.department_id
FROM workspace.instacart_bronze.products_raw p
WHERE p.product_id IS NOT NULL
  AND p.product_name IS NOT NULL
  AND EXISTS (SELECT 1 FROM aisles_clean a WHERE a.aisle_id = p.aisle_id)
  AND EXISTS (SELECT 1 FROM departments_clean d WHERE d.department_id = p.department_id);

DESCRIBE TABLE products_clean;
