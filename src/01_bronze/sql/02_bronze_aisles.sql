-- saved-query name: 02_bronze_aisles
-- paste the approved Databricks SQL for this task below
-- replaces the bronze table using the approved explicit source schema

CREATE OR REPLACE TABLE workspace.default.aisles
USING DELTA
COMMENT 'bronze copy of the instacart aisles csv'
AS
SELECT
  aisle_id,
  aisle,
  _rescued_data
FROM read_files(
  '/Volumes/workspace/default/ftw-b12-de/shared/week06/instacart_csv/aisles.csv',
  format => 'csv',
  header => true,
  schema => 'aisle_id INT, aisle STRING',
  rescuedDataColumn => '_rescued_data'
);
