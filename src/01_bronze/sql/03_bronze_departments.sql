-- Owner: Nadine
-- Name: 03 - Bronze Departments
-- Purpose: Load Instacart department records into the Bronze Delta table using an explicit schema while retaining rescued data.
-- Grain: One row per department, uniquely identified by department_id.

USE CATALOG workspace;
USE SCHEMA instacart_bronze;

CREATE OR REPLACE TABLE departments 
USING DELTA
COMMENT 'bronze copy of the instacart departments csv'
AS
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