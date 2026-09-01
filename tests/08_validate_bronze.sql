-- ============================================================
-- 6. ORDERS - BRONZE VALIDATION
-- Owner: Angela
-- Table: workspace.instacart_bronze.orders_raw
-- Grain: One row = one order placed by one user.
-- ============================================================

SELECT
    COUNT(*) AS total_rows,

    -- Key checks: null and duplicate ids
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicate_order_ids,
    SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_ids,

    -- eval_set profiling
    SUM(CASE WHEN eval_set IS NULL THEN 1 ELSE 0 END) AS null_eval_set,
    COUNT(DISTINCT eval_set) AS distinct_eval_set_count,
    SORT_ARRAY(COLLECT_SET(eval_set)) AS possible_eval_set_values,

    -- Order number should be positive
    SUM(
        CASE
            WHEN order_number IS NULL
              OR order_number <= 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_order_number,

    -- Day of week profiling
    SUM(CASE WHEN order_dow IS NULL THEN 1 ELSE 0 END) AS null_order_dow,
    COUNT(DISTINCT order_dow) AS distinct_order_dow_count,
    SORT_ARRAY(COLLECT_SET(order_dow)) AS possible_order_dow_values,

    -- Order hour profiling
    SUM(CASE WHEN order_hour_of_day IS NULL THEN 1 ELSE 0 END) AS null_order_hour,
    COUNT(DISTINCT order_hour_of_day) AS distinct_order_hour_count,
    SORT_ARRAY(COLLECT_SET(order_hour_of_day)) AS possible_order_hour_values,

    -- First orders should not have a previous order interval
    SUM(
        CASE
            WHEN order_number = 1
             AND days_since_prior_order IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS first_orders_with_prior_days,

    -- Later orders should normally have a previous order interval
    SUM(
        CASE
            WHEN order_number > 1
             AND days_since_prior_order IS NULL
            THEN 1
            ELSE 0
        END
    ) AS later_orders_missing_prior_days,

    -- Values should not be negative
    SUM(
        CASE
            WHEN days_since_prior_order < 0
            THEN 1
            ELSE 0
        END
    ) AS negative_days_since_prior_order

FROM workspace.instacart_bronze.orders_raw;

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