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
