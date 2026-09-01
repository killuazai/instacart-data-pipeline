-- ============================================================
-- 4. PRODUCTS - BRONZE VALIDATION
-- Owner: Ina
-- Table: workspace.instacart_bronze.products_raw
-- Grain: One row = one product
-- ============================================================

-- ============================================================
-- 4.1. ROW COUNT
-- Confirm that the source data was successfully loaded.
-- ============================================================

SELECT
    COUNT(*) AS total_rows
FROM workspace.instacart_bronze.products_raw;


-- ============================================================
-- 4.2. CHECK NULL VALUES
-- Required fields should not contain missing values.
-- ============================================================

SELECT
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END)
        AS null_product_id,

    SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END)
        AS null_product_name,

    SUM(CASE WHEN aisle_id IS NULL THEN 1 ELSE 0 END)
        AS null_aisle_id,

    SUM(CASE WHEN department_id IS NULL THEN 1 ELSE 0 END)
        AS null_department_id

FROM workspace.instacart_bronze.products_raw;


-- ============================================================
-- 4.3. CHECK INVALID NUMERIC VALUES
-- IDs should contain positive values.
-- ============================================================

SELECT *
FROM workspace.instacart_bronze.products_raw

WHERE
       product_id <= 0
    OR aisle_id <= 0
    OR department_id <= 0;


-- ============================================================
-- 4.4. CHECK BLANK OR WHITESPACE-ONLY PRODUCT NAMES
-- product_name should contain real text, not just spaces.
-- ============================================================

SELECT *
FROM workspace.instacart_bronze.products_raw

WHERE product_name IS NULL
   OR TRIM(product_name) = '';


-- ============================================================
-- 4.5. CHECK EXACT DUPLICATE ROWS
-- Identify records where all column values are duplicated.
-- ============================================================

SELECT
    product_id,
    product_name,
    aisle_id,
    department_id,
    COUNT(*) AS occurrence_count

FROM workspace.instacart_bronze.products_raw

GROUP BY
    product_id,
    product_name,
    aisle_id,
    department_id

HAVING COUNT(*) > 1;


-- ============================================================
-- 4.6. CHECK DUPLICATE PRODUCT_ID
-- product_id is the primary key - each value should appear once.
-- ============================================================

SELECT
    product_id,
    COUNT(*) AS occurrence_count

FROM workspace.instacart_bronze.products_raw

GROUP BY
    product_id

HAVING COUNT(*) > 1;


-- ============================================================
-- 4.7. CHECK UNMATCHED AISLE_ID
-- Every aisle_id should exist in the aisles lookup table.
-- ============================================================

SELECT p.*
FROM workspace.instacart_bronze.products_raw p
LEFT JOIN workspace.instacart_bronze.aisles_raw a
    ON p.aisle_id = a.aisle_id
WHERE p.aisle_id IS NOT NULL
  AND a.aisle_id IS NULL;


-- ============================================================
-- 4.8. CHECK UNMATCHED DEPARTMENT_ID
-- Every department_id should exist in the departments lookup table.
-- ============================================================

SELECT p.*
FROM workspace.instacart_bronze.products_raw p
LEFT JOIN workspace.instacart_bronze.departments_raw d
    ON p.department_id = d.department_id
WHERE p.department_id IS NOT NULL
  AND d.department_id IS NULL;


-- ============================================================
-- 4.9. BASIC DATA PROFILE
-- Summarize the Bronze dataset for documentation.
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_id) AS distinct_products,
    COUNT(DISTINCT aisle_id) AS distinct_aisles_referenced,
    COUNT(DISTINCT department_id) AS distinct_departments_referenced

FROM workspace.instacart_bronze.products_raw;

-- ============================================================
-- 6. ORDER PRODUCTS TRAIN - BRONZE VALIDATION
-- Owner: Maeve
-- Table: workspace.instacart_bronze.order_products_train_raw
-- Grain: One row = one product included in one order
-- ============================================================

-- ============================================================
-- 6.1. ROW COUNT
-- Confirm that the source data was successfully loaded.
-- ============================================================

SELECT
    COUNT(*) AS total_rows
FROM workspace.instacart_bronze.order_products_train;


-- ============================================================
-- 6.2. CHECK NULL VALUES
-- Required fields should not contain missing values.
-- ============================================================

SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END)
        AS null_order_id,

    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END)
        AS null_product_id,

    SUM(CASE WHEN add_to_cart_order IS NULL THEN 1 ELSE 0 END)
        AS null_add_to_cart_order,

    SUM(CASE WHEN reordered IS NULL THEN 1 ELSE 0 END)
        AS null_reordered

FROM workspace.instacart_bronze.order_products_train;


-- ============================================================
-- 6.3. CHECK INVALID NUMERIC VALUES
-- IDs and cart positions should contain positive values.
-- ============================================================

SELECT *
FROM workspace.instacart_bronze.order_products_train

WHERE
       order_id <= 0
    OR product_id <= 0
    OR add_to_cart_order <= 0;


-- ============================================================
-- 6.4. VALIDATE REORDERED FLAG
-- reordered should contain only:
-- 0 = not reordered
-- 1 = reordered
-- ============================================================

SELECT
    reordered,
    COUNT(*) AS row_count

FROM workspace.instacart_bronze.order_products_train

GROUP BY reordered
ORDER BY reordered;


-- Check specifically for invalid reordered values
SELECT *
FROM workspace.instacart_bronze.order_products_train

WHERE reordered NOT IN (0, 1)
   OR reordered IS NULL;


-- ============================================================
-- 6.5. CHECK EXACT DUPLICATE ROWS
-- Identify records where all column values are duplicated.
-- ============================================================

SELECT
    order_id,
    product_id,
    add_to_cart_order,
    reordered,
    COUNT(*) AS occurrence_count

FROM workspace.instacart_bronze.order_products_train

GROUP BY
    order_id,
    product_id,
    add_to_cart_order,
    reordered

HAVING COUNT(*) > 1;


-- ============================================================
-- 6.6. CHECK DUPLICATE ORDER-PRODUCT COMBINATIONS
-- A product should appear only once within the same order.
-- ============================================================

SELECT
    order_id,
    product_id,
    COUNT(*) AS occurrence_count

FROM workspace.instacart_bronze.order_products_train

GROUP BY
    order_id,
    product_id

HAVING COUNT(*) > 1;


-- ============================================================
-- 6.7. CHECK DUPLICATE CART POSITIONS
-- Each cart position should belong to only one product
-- within the same order.
-- ============================================================

SELECT
    order_id,
    add_to_cart_order,
    COUNT(*) AS occurrence_count

FROM workspace.instacart_bronze.order_products_train

GROUP BY
    order_id,
    add_to_cart_order

HAVING COUNT(*) > 1;


-- ============================================================
-- 6.8. CHECK CART ORDER 
-- Make sure that the value is positive
-- ============================================================

SELECT *
FROM workspace.instacart_bronze.order_products_train
WHERE add_to_cart_order <= 0
   OR add_to_cart_order IS NULL;

-- ============================================================
-- 6.9. BASIC DATA PROFILE
-- Summarize the Bronze dataset for documentation.
-- ============================================================

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT product_id) AS distinct_products,
    MIN(add_to_cart_order) AS min_cart_position,
    MAX(add_to_cart_order) AS max_cart_position

FROM workspace.instacart_bronze.order_products_train;