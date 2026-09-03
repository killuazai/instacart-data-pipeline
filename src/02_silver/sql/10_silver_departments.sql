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
-- saved-query name: 10_silver_departments
-- paste the approved Databricks SQL for this task below

CREATE OR REPLACE TABLE silver_departments AS

SELECT DISTINCT
    CAST(department_id AS INT) AS department_id,
    TRIM(LOWER(department)) AS department

FROM bronze_departments

WHERE department_id IS NOT NULL
  AND department IS NOT NULL
  AND TRIM(department) != '';

  SELECT *
FROM silver_departments
ORDER BY department_id;
