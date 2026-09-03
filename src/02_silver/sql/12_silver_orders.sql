-- Owner: Ina
-- Name: 12 - Silver Orders
-- Purpose: Clean the Bronze orders table - drop null keys, validate day-of-week and hour ranges.
-- Grain: One row per order, uniquely identified by order_id.

CREATE OR REPLACE TABLE orders_clean AS
SELECT
    order_id,
    user_id,
    order_number,
    order_dow,
    order_hour_of_day,
    days_since_prior_order          -- NULL preserved: meaningful for a user's first order
FROM instacart_bronze.orders
WHERE order_id IS NOT NULL
  AND user_id IS NOT NULL
  AND order_dow BETWEEN 0 AND 6
  AND order_hour_of_day BETWEEN 0 AND 23;

DESCRIBE TABLE orders_clean;