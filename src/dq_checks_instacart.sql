-- ============================================================
-- DAY 7 GROUP EXERCISE: Make Your Instacart Pipeline Observable
-- ============================================================
-- Schema matches the Day 7 deck exactly:
-- executed_at, dataset, check_name, check_type, status,
-- fail_count, total_count, fail_pct, threshold, severity

USE CATALOG workspace;
USE SCHEMA instacart_gold;

CREATE TABLE IF NOT EXISTS dq_check_results (
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
-- Are required order identifiers missing?
-- ============================================================
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'orders_clean' AS dataset,
    'order_id_not_null' AS check_name,
    'NULL' AS check_type,
    CASE WHEN SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS fail_count,
    COUNT(*) AS total_count,
    ROUND(SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM instacart_silver.orders_clean;


-- ============================================================
-- CHECK 2: UNIQUE
-- Is product_id unexpectedly duplicated in the product dimension?
-- ============================================================
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'products_clean' AS dataset,
    'product_id_unique' AS check_name,
    'UNIQUE' AS check_type,
    CASE WHEN COUNT(*) - COUNT(DISTINCT product_id) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) - COUNT(DISTINCT product_id) AS fail_count,
    COUNT(*) AS total_count,
    ROUND((COUNT(*) - COUNT(DISTINCT product_id)) / COUNT(*) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM instacart_silver.products_clean;


-- ============================================================
-- CHECK 3: RANGE / ACCEPTED VALUE
-- Is order_hour_of_day within the valid 0-23 range?
-- ============================================================
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'orders_clean' AS dataset,
    'valid_order_hour' AS check_name,
    'RANGE' AS check_type,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS fail_count,
    (SELECT COUNT(*) FROM instacart_silver.orders_clean) AS total_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM instacart_silver.orders_clean) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM instacart_silver.orders_clean
WHERE order_hour_of_day NOT BETWEEN 0 AND 23;


-- ============================================================
-- CHECK 4: REFERENTIAL INTEGRITY
-- Does every fact row's product_id resolve to a real product?
-- ============================================================
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'gold_fact_order_product' AS dataset,
    'fact_product_fk' AS check_name,
    'REFERENTIAL INTEGRITY' AS check_type,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS status,
    COUNT(*) AS fail_count,
    (SELECT COUNT(*) FROM gold_fact_order_product) AS total_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM gold_fact_order_product) * 100, 4) AS fail_pct,
    0.0 AS threshold,
    'CRITICAL' AS severity
FROM gold_fact_order_product f
LEFT JOIN gold_dim_product p ON f.product_id = p.product_id
WHERE f.product_id IS NOT NULL AND p.product_id IS NULL;


-- ============================================================
-- CHECK 5: VOLUME
-- Did orders_clean receive roughly the expected row count?
-- Threshold: flag if row count drops more than 1% below expected.
-- ============================================================
INSERT INTO dq_check_results
SELECT
    CURRENT_TIMESTAMP AS executed_at,
    'orders_clean' AS dataset,
    'orders_row_volume' AS check_name,
    'VOLUME' AS check_type,
    CASE WHEN COUNT(*) >= 3421083 * 0.99 THEN 'PASS' ELSE 'FAIL' END AS status,
    CASE WHEN COUNT(*) >= 3421083 * 0.99 THEN 0 ELSE 3421083 - COUNT(*) END AS fail_count,
    COUNT(*) AS total_count,
    ROUND((3421083 - COUNT(*)) / 3421083 * 100, 4) AS fail_pct,
    1.0 AS threshold,
    'WARNING' AS severity
FROM instacart_silver.orders_clean;


-- ============================================================
-- SANITY CHECK: view what was just inserted
-- ============================================================
SELECT * FROM dq_check_results ORDER BY executed_at DESC;
