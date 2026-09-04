-- Owner: Nadine
-- Name: 01 - Setup
-- Purpose: Create the Bronze, Silver, Gold, and Analytics schemas and validate the six approved Instacart source CSV files.
-- Grain: One validation summary row for the Instacart source folder.

CREATE SCHEMA IF NOT EXISTS workspace.instacart_bronze;
CREATE SCHEMA IF NOT EXISTS workspace.instacart_silver;
CREATE SCHEMA IF NOT EXISTS workspace.instacart_gold;
CREATE SCHEMA IF NOT EXISTS workspace.instacart_analytics;

WITH expected_files AS (
  SELECT explode(
    array(
      'aisles.csv',
      'departments.csv',
      'order_products__prior.csv',
      'order_products__train.csv',
      'orders.csv',
      'products.csv'
    )
  ) AS file_name
),
actual_files AS (
  SELECT
    regexp_extract(path, '([^/]+)$', 1) AS file_name
  FROM read_files(
    '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/*.csv',
    format => 'binaryFile'
  )
),
file_checks AS (
  SELECT
    (SELECT COUNT(*) FROM actual_files) AS actual_file_count,
    (
      SELECT COUNT(*)
      FROM actual_files a
      LEFT ANTI JOIN expected_files e
        ON a.file_name = e.file_name
    ) AS unexpected_file_count,
    (
      SELECT COUNT(*)
      FROM expected_files e
      LEFT ANTI JOIN actual_files a
        ON e.file_name = a.file_name
    ) AS missing_file_count
)
SELECT
  actual_file_count,
  unexpected_file_count,
  missing_file_count,
  assert_true(
    actual_file_count = 6,
    'source folder must contain exactly six csv files'
  ) AS file_count_check,
  assert_true(
    unexpected_file_count = 0,
    'source folder contains an unexpected csv file'
  ) AS unexpected_file_check,
  assert_true(
    missing_file_count = 0,
    'one or more required source files are missing'
  ) AS missing_file_check
FROM file_checks;