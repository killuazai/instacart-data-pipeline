-- ============================================================
-- DQ DASHBOARD QUERIES
-- One query per required panel: PASS RATE, FAILED CHECKS,
-- FAILURES BY DATASET, FAILURES BY CHECK TYPE, LAST CHECKED
-- ============================================================

USE CATALOG workspace;
USE SCHEMA instacart_analytics;


-- ============================================================
-- PANEL 1: PASS RATE
-- Single number: % of all checks currently passing.
-- ============================================================
SELECT
    ROUND(SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pass_rate_pct
FROM dq_check_results;


-- ============================================================
-- PANEL 2: FAILED CHECKS
-- List of every check currently failing, most severe first.
-- ============================================================
SELECT
    dataset,
    check_name,
    check_type,
    fail_count,
    total_count,
    fail_pct,
    severity,
    executed_at
FROM dq_check_results
WHERE status = 'FAIL'
ORDER BY
    CASE severity WHEN 'CRITICAL' THEN 1 WHEN 'WARNING' THEN 2 ELSE 3 END,
    fail_pct DESC;


-- ============================================================
-- PANEL 3: FAILURES BY DATASET
-- Which tables are failing the most checks right now?
-- ============================================================
SELECT
    dataset,
    COUNT(*) AS total_checks,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed_checks,
    ROUND(SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS failure_rate_pct
FROM dq_check_results
GROUP BY dataset
ORDER BY failed_checks DESC;


-- ============================================================
-- PANEL 4: FAILURES BY CHECK TYPE
-- Which category of check (NULL, UNIQUE, RANGE, etc.) is
-- catching the most problems?
-- ============================================================
SELECT
    check_type,
    COUNT(*) AS total_checks,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed_checks,
    ROUND(SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS failure_rate_pct
FROM dq_check_results
GROUP BY check_type
ORDER BY failed_checks DESC;


-- ============================================================
-- PANEL 5: LAST CHECKED
-- When did each check last run? Answers "is this stale?"
-- ============================================================
SELECT
    dataset,
    check_name,
    status,
    executed_at AS last_checked
FROM dq_check_results
ORDER BY executed_at DESC;