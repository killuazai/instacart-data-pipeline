-- Owner: Ina
-- Name: 09 - Silver Aisles
-- Purpose: Clean the Bronze aisles table - trim whitespace, standardize casing, drop null keys.
-- Grain: One row per aisle, uniquely identified by aisle_id.

CREATE OR REPLACE TABLE aisles_clean AS
SELECT
    aisle_id,
    INITCAP(TRIM(aisle)) AS aisle
FROM instacart_bronze.aisles
WHERE aisle_id IS NOT NULL;

DESCRIBE TABLE aisles_clean;