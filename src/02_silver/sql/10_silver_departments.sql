-- Owner: Ina
-- Name: 10 - Silver Department
-- Purpose: Clean the Bronze departments table - trim whitespace, standardize casing, drop null keys.
-- Grain: One row per department, uniquely identified by department_id.

CREATE OR REPLACE TABLE departments_clean AS
SELECT
    department_id,
    INITCAP(TRIM(department)) AS department
FROM instacart_bronze.departments
WHERE department_id IS NOT NULL;

DESCRIBE TABLE departments_clean;