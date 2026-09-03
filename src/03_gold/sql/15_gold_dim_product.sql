-- Owner: Cath
-- Name: 15 - Gold Dim Product
-- Purpose: Build a product dimension with denormalized aisle and department names.
-- Grain: One row per product, uniquely identified by product_id.

CREATE OR REPLACE TABLE gold_dim_product AS
SELECT
    p.product_id,
    p.product_name,
    p.aisle_id,
    a.aisle AS aisle_name,
    p.department_id,
    d.department AS department_name
FROM instacart_silver.products_clean p
LEFT JOIN instacart_silver.aisles_clean a ON p.aisle_id = a.aisle_id
LEFT JOIN instacart_silver.departments_clean d ON p.department_id = d.department_id;

DESCRIBE TABLE gold_dim_product;