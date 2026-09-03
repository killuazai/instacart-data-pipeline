-- Owner: Maeve
-- Name: 21 - Analytics Product and Department Frequency
-- Purpose: Identify the products and departments purchased most frequently.
-- Grain: Two outputs: one row per department and one row per product, limited to the top 50 products.

USE CATALOG workspace;
USE SCHEMA instacart_analytics;

-- Department-level answer
CREATE OR REPLACE TABLE analytics_top_departments AS
SELECT
  p.department_id,
  p.department_name,
  COUNT(*) AS order_line_count,
  COUNT(DISTINCT f.order_id) AS distinct_orders
FROM workspace.instacart_gold.gold_fact_order_product f
INNER JOIN workspace.instacart_gold.gold_dim_product p
  ON f.product_id = p.product_id
GROUP BY
  p.department_id,
  p.department_name;

-- Product-level answer
CREATE OR REPLACE TABLE analytics_top_products AS
SELECT
  p.product_id,
  p.product_name,
  p.department_name,
  p.aisle_name,
  COUNT(*) AS order_line_count,
  COUNT(DISTINCT f.order_id) AS distinct_orders
FROM workspace.instacart_gold.gold_fact_order_product f
INNER JOIN workspace.instacart_gold.gold_dim_product p
  ON f.product_id = p.product_id
GROUP BY
  p.product_id,
  p.product_name,
  p.department_name,
  p.aisle_name
ORDER BY order_line_count DESC
LIMIT 50;

-- Preview the department-level answer
SELECT *
FROM analytics_top_departments
ORDER BY order_line_count DESC;

-- Preview the product-level answer
SELECT *
FROM analytics_top_products
ORDER BY order_line_count DESC;