-- Owner: Cath
-- Name: 16_gold_dim_order.sql
-- Purpose: Build an order dimension with customer and time attributes.
-- Grain: One row per order, uniquely identified by order_id.

CREATE OR REPLACE TABLE gold_dim_order AS
SELECT
    order_id,
    user_id,
    order_number,
    order_dow,
    CASE order_dow
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS order_day_name,
    order_hour_of_day,
    days_since_prior_order,
    CASE
        WHEN days_since_prior_order IS NULL THEN 'First Order'
        WHEN days_since_prior_order <= 7 THEN 'Within 1 Week'
        WHEN days_since_prior_order <= 14 THEN '1-2 Weeks'
        WHEN days_since_prior_order <= 30 THEN '2-4 Weeks'
        ELSE 'Over 30 Days'
    END AS order_frequency_category
FROM instacart_silver.orders_clean;

DESCRIBE TABLE gold_dim_order;