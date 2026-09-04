-- Owner: Maeve
-- Name: 24 - Analytics Product Pairs
-- Purpose: Find product pairs most frequently purchased in the same order, restricted to the
--          top 200 products by volume so the self-join stays tractable at fact-table scale.
-- Grain: One row per unordered product pair (product_a, product_b), top 50 by co-purchase count.

CREATE OR REPLACE TABLE analytics_product_pairs AS
WITH top_products AS (
    SELECT product_id
    FROM workspace.instacart_gold.gold_fact_order_product
    GROUP BY product_id
    ORDER BY COUNT(*) DESC
    LIMIT 200
),
filtered_fact AS (
    SELECT f.order_id, f.product_id
    FROM workspace.instacart_gold.gold_fact_order_product f
    JOIN top_products t ON f.product_id = t.product_id
)
SELECT
    p1.product_name AS product_a,
    p2.product_name AS product_b,
    COUNT(*) AS times_bought_together
FROM filtered_fact f1
JOIN filtered_fact f2
    ON f1.order_id = f2.order_id
    AND f1.product_id < f2.product_id
JOIN workspace.instacart_gold.gold_dim_product p1 ON f1.product_id = p1.product_id
JOIN workspace.instacart_gold.gold_dim_product p2 ON f2.product_id = p2.product_id
GROUP BY p1.product_name, p2.product_name
ORDER BY times_bought_together DESC
LIMIT 50;

SELECT * FROM analytics_product_pairs;