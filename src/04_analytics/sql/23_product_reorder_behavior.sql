-- Owner: Maeve
-- Name: 23 - Analytics Reorder Rates
-- Purpose: Rank products by reorder rate, restricted to products with enough volume for the rate to be meaningful.
-- Grain: One row per product, minimum 500 order-lines, top 50 by reorder rate.

CREATE OR REPLACE TABLE analytics_reorder_rates AS
SELECT
    p.product_name,
    p.department_name,
    COUNT(*) AS total_order_lines,
    SUM(CASE WHEN f.reordered THEN 1 ELSE 0 END) AS reorder_count,
    ROUND(AVG(CASE WHEN f.reordered THEN 1.0 ELSE 0.0 END), 4) AS reorder_rate
FROM workspace.instacart_gold.gold_fact_order_product f
JOIN workspace.instacart_gold.gold_dim_product p ON f.product_id = p.product_id
GROUP BY p.product_name, p.department_name
HAVING COUNT(*) >= 500
ORDER BY reorder_rate DESC
LIMIT 50;

SELECT * FROM analytics_reorder_rates;