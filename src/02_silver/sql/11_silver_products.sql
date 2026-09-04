-- Owner: Ina
-- Name: 11 - Silver Products
-- Purpose: Clean the Bronze products table - trim names, strip stray backslash artifacts,
--          drop rows with an aisle_id or department_id that doesn't exist in Silver.
-- Grain: One row per product, uniquely identified by product_id.
-- CHR(92) represents the backslash character: \

CREATE OR REPLACE TABLE products_clean AS
SELECT
    p.product_id,
    TRIM(REPLACE(p.product_name, CHR(92), '')) AS product_name, 
    p.aisle_id,
    p.department_id
FROM instacart_bronze.products p
WHERE p.product_id IS NOT NULL
  AND p.product_name IS NOT NULL
  AND EXISTS (SELECT 1 FROM aisles_clean a WHERE a.aisle_id = p.aisle_id)
  AND EXISTS (SELECT 1 FROM departments_clean d WHERE d.department_id = p.department_id);

DESCRIBE TABLE products_clean;