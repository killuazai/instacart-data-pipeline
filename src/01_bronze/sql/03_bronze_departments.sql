-- Owner: Nadine
-- Name: 03 - Bronze Departments
-- Purpose: Load Instacart department records into the Bronze Delta table using an explicit schema while retaining rescued data.
-- Grain: One row per department, uniquely identified by department_id.

CREATE TABLE IF NOT EXISTS workspace.instacart_bronze.departments (
  department_id INT,
  department STRING,
  _rescued_data STRING
)
USING DELTA
COMMENT 'bronze copy of the instacart departments csv';

INSERT OVERWRITE TABLE workspace.instacart_bronze.departments
SELECT
  department_id,
  department,
  _rescued_data
FROM read_files(
  '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/departments.csv',
  format => 'csv',
  header => true,
  schema => 'department_id INT, department STRING',
  rescuedDataColumn => '_rescued_data'
);
-- saved-query name: 03_bronze_departments
-- paste the approved Databricks SQL for this task below

CREATE OR REPLACE TABLE `bronze_departments` AS
SELECT *
FROM read_files(
    'r2://ftw-b12-dataengineering@6338489909d41c2f78a0a2345a684267.r2.cloudflarestorage.com/shared/week06/instacart_csv/departments.csv',
    format => 'csv',
    header => true
);

SELECT *
FROM `bronze_departments`;


