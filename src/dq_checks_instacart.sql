-- ============================================================
-- DAY 7 GROUP EXERCISE: Make Your Instacart Pipeline Observable
-- Target: workspace.instacart_silver.order_products_clean
-- Columns: order_id, product_id, add_to_cart_order, reordered, source_file
--
-- WHY THESE SPECIFIC CHECKS:
-- This table is built by UNION-ing two Bronze source files
-- (order_products_prior, order_products_train) and filtering against
-- TWO parent tables (orders_clean, products_clean). Those two facts
-- create two distinct, realistic failure modes that a single generic
-- check per category would miss:
--   1. A referential integrity check on only ONE side (order_id) would
--      miss a broken product_id relationship - this is the exact bug
--      found earlier in this pipeline's history.
--   2. A single combined VOLUME check could pass even if one entire
--      source file (e.g. 'train') silently failed to load, as long as
--      the OTHER source file's volume covers for it in the combined
--      total. Checking each source_file's volume separately catches
--      that a single aggregate check cannot.
-- So several categories below have two checks, not one, each aimed at
-- a different specific risk rather than restating the same idea twice.
-- ============================================================

USE CATALOG workspace;
USE SCHEMA instacart_gold;

CREATE TABLE IF NOT EXISTS dq_check_result (
    executed_at   TIMESTAMP,
    dataset       STRING,
    check_name    STRING,
    check_type    STRING,
    status        STRING,
    fail_count    BIGINT,
    total_count   BIGINT,
    fail_pct      DOUBLE,
    threshold     DOUBLE,
    severity      STRING
);


-- ============================================================
-- CHECK 1: NULL
-- All three structurally required columns in one check - a row
-- missing any of these can't be used for anything downstream.
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'required_columns_not_null' AS check_name,
    'NULL' AS check_type,
    CASE WHEN SUM(CASE WHEN order_id IS NULL
                          OR product_id IS NULL
                          OR add_to_cart_order IS NULL
                     THEN 1 ELSE 0 END) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status,
    SUM(CASE WHEN order_id IS NULL
                OR product_id IS NULL
                OR add_to_cart_order IS NULL
           THEN 1 ELSE 0 END) AS fail_count,
    COUNT(*) AS total_count,
    ROUND(SUM(CASE WHEN order_id IS NULL
                       OR product_id IS NULL
                       OR add_to_cart_order IS NULL
                  THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM workspace.instacart_silver.order_products_clean;


-- ============================================================
-- CHECK 2a: UNIQUE - primary grain
-- (order_id, product_id) is the documented grain: one row per
-- product per order. A duplicate here means the same product was
-- somehow recorded twice on one order - a real ingestion error.
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'grain_order_product_unique' AS check_name,
    'UNIQUE' AS check_type,
    CASE WHEN COUNT(*) - COUNT(DISTINCT struct(order_id, product_id)) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) - COUNT(DISTINCT struct(order_id, product_id)) AS fail_count,
    COUNT(*) AS total_count,
    ROUND((COUNT(*) - COUNT(DISTINCT struct(order_id, product_id))) / COUNT(*) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM workspace.instacart_silver.order_products_clean;


-- ============================================================
-- CHECK 2b: UNIQUE - cart position, a different failure mode
-- (order_id, add_to_cart_order) should also be unique: two
-- different products can't occupy the same cart slot in one order.
-- This catches a DIFFERENT anomaly than 2a - two distinct products
-- both claiming position #1 in the same order, which 2a alone
-- would not detect (different product_ids, so 2a sees no duplicate).
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'cart_position_unique' AS check_name,
    'UNIQUE' AS check_type,
    CASE WHEN COUNT(*) - COUNT(DISTINCT struct(order_id, add_to_cart_order)) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) - COUNT(DISTINCT struct(order_id, add_to_cart_order)) AS fail_count,
    COUNT(*) AS total_count,
    ROUND((COUNT(*) - COUNT(DISTINCT struct(order_id, add_to_cart_order))) / COUNT(*) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM workspace.instacart_silver.order_products_clean;


-- ============================================================
-- CHECK 3a: RANGE
-- add_to_cart_order must be a positive integer - position 0 or
-- negative is not a valid cart slot.
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'valid_add_to_cart_order' AS check_name,
    'RANGE' AS check_type,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS fail_count,
    (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean) AS total_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM workspace.instacart_silver.order_products_clean
WHERE add_to_cart_order IS NULL OR add_to_cart_order <= 0;


-- ============================================================
-- CHECK 3b: ACCEPTED VALUE
-- source_file must only ever be 'prior' or 'train' - this column
-- exists specifically to prove the Bronze union was built correctly.
-- Any other value means the union logic itself has been corrupted
-- or a third, unexpected source got merged in.
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'valid_source_file' AS check_name,
    'ACCEPTED VALUE' AS check_type,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS fail_count,
    (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean) AS total_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM workspace.instacart_silver.order_products_clean
WHERE source_file NOT IN ('prior', 'train') OR source_file IS NULL;


-- ============================================================
-- CHECK 4a: REFERENTIAL INTEGRITY - order side
-- Every order_id must exist in orders_clean.
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'order_id_fk' AS check_name,
    'REFERENTIAL INTEGRITY' AS check_type,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS fail_count,
    (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean) AS total_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM workspace.instacart_silver.order_products_clean op
LEFT JOIN workspace.instacart_silver.orders_clean o ON op.order_id = o.order_id
WHERE op.order_id IS NOT NULL AND o.order_id IS NULL;


-- ============================================================
-- CHECK 4b: REFERENTIAL INTEGRITY - product side
-- Every product_id must exist in products_clean. Checked
-- SEPARATELY from 4a on purpose: checking only order_id would have
-- missed this exact relationship in an earlier version of this
-- pipeline, where the product-side filter was absent from the build.
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'product_id_fk' AS check_name,
    'REFERENTIAL INTEGRITY' AS check_type,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS fail_count,
    (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean) AS total_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM workspace.instacart_silver.order_products_clean op
LEFT JOIN workspace.instacart_silver.products_clean p ON op.product_id = p.product_id
WHERE op.product_id IS NOT NULL AND p.product_id IS NULL;


-- ============================================================
-- CHECK 5a: VOLUME - combined total
-- Expected: 33,819,106 (32,434,489 prior + 1,384,617 train).
-- Threshold: flag if total drops more than 1% below expected.
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'total_row_volume' AS check_name,
    'VOLUME' AS check_type,
    CASE WHEN COUNT(*) >= 33819106 * 0.99 THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE WHEN COUNT(*) >= 33819106 * 0.99 THEN 0 ELSE 33819106 - COUNT(*) END AS fail_count,
    COUNT(*) AS total_count,
    ROUND((33819106 - COUNT(*)) / 33819106 * 100, 4) AS fail_pct,
    1.0 AS threshold,
    'WARNING' AS severity
FROM workspace.instacart_silver.order_products_clean;


-- ============================================================
-- CHECK 5b: VOLUME - by source_file, checked separately
-- A combined total check (5a) can pass even if ONE ENTIRE SOURCE
-- FILE silently failed to load, as long as it's a small enough
-- share of the total (e.g. train is only ~4% of all rows - it
-- could vanish completely and 5a might still read within 1% of
-- expected, since prior alone is 32,434,489 vs. combined
-- 33,819,106, only a 4.1% drop). Checking each source's volume
-- independently closes that blind spot.
-- ============================================================
INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'prior_source_volume' AS check_name,
    'VOLUME' AS check_type,
    CASE WHEN COUNT(*) >= 32434489 * 0.99 THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE WHEN COUNT(*) >= 32434489 * 0.99 THEN 0 ELSE 32434489 - COUNT(*) END AS fail_count,
    COUNT(*) AS total_count,
    ROUND((32434489 - COUNT(*)) / 32434489 * 100, 4) AS fail_pct,
    1.0 AS threshold,
    'WARNING' AS severity
FROM workspace.instacart_silver.order_products_clean
WHERE source_file = 'prior';

INSERT INTO dq_check_result
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'order_products_clean' AS dataset,
    'train_source_volume' AS check_name,
    'VOLUME' AS check_type,
    CASE WHEN COUNT(*) >= 1384617 * 0.99 THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE WHEN COUNT(*) >= 1384617 * 0.99 THEN 0 ELSE 1384617 - COUNT(*) END AS fail_count,
    COUNT(*) AS total_count,
    ROUND((1384617 - COUNT(*)) / 1384617 * 100, 4) AS fail_pct,
    1.0 AS threshold,
    'WARNING' AS severity
FROM workspace.instacart_silver.order_products_clean
WHERE source_file = 'train';


-- ============================================================
-- SANITY CHECK: view what was just inserted
-- ============================================================
SELECT * FROM dq_check_result ORDER BY executed_at DESC;