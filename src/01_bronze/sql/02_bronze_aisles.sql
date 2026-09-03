-- Owner: Nadine
-- Name: 02 - Bronze Aisles
-- Purpose: Load Instacart aisle records into the Bronze Delta table using an explicit schema while retaining rescued data.
-- Grain: One row per aisle, uniquely identified by aisle_id.

USE CATALOG workspace;
CREATE SCHEMA IF NOT EXISTS instacart_bronze;
USE SCHEMA instacart_bronze;

CREATE OR REPLACE TABLE aisles
USING DELTA -- create this table as a Delta Lake table to add features on top of ordinary files, such as ACID transactions
COMMENT 'bronze copy of the instacart aisles csv' -- adds a description to the table as metadata.
AS
SELECT
  aisle_id,
  aisle,
  _rescued_data -- to capture source data that does not fit the schema specified
FROM read_files(
  '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/aisles.csv',
  format => 'csv',
  header => true,
  schema => 'aisle_id INT, aisle STRING',
  rescuedDataColumn => '_rescued_data'
);