-- Owner: Maeve
-- Name: 22 - Analytics Customer Behavior by Day and Hour
-- Purpose: Analyze purchasing patterns by day and hour and calculate average product lines per order by day.
-- Grain: Two outputs: one row per day/hour combination and one row per day.

USE CATALOG workspace;
USE SCHEMA instacart_analytics;

-- Day-and-hour purchasing patterns
CREATE OR REPLACE TABLE analytics_day_hour_patterns AS
SELECT
  o.order_dow,
  o.order_day_name,
  o.order_hour_of_day,
  COUNT(*) AS order_line_count,
  COUNT(DISTINCT f.order_id) AS distinct_orders
FROM workspace.instacart_gold.gold_fact_order_product f
INNER JOIN workspace.instacart_gold.gold_dim_order o
  ON f.order_id = o.order_id
GROUP BY
  o.order_dow,
  o.order_day_name,
  o.order_hour_of_day;

-- Daily basket size calculated from the day/hour summary
CREATE OR REPLACE TABLE analytics_basket_size_by_day AS
SELECT
  order_dow,
  order_day_name,
  SUM(order_line_count) AS order_line_count,
  SUM(distinct_orders) AS distinct_orders,
  TRY_DIVIDE(
    SUM(order_line_count),
    SUM(distinct_orders)
  ) AS avg_items_per_order
FROM analytics_day_hour_patterns
GROUP BY
  order_dow,
  order_day_name;

-- Preview the day/hour patterns in chronological order
SELECT *
FROM analytics_day_hour_patterns
ORDER BY
  order_dow,
  order_hour_of_day;

-- Preview the daily basket sizes
SELECT *
FROM analytics_basket_size_by_day
ORDER BY
  order_dow;