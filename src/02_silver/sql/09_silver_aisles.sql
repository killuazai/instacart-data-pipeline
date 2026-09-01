-- saved-query name: 09_silver_aisles
-- paste the approved Databricks SQL for this task below
-- standardizes aisle identifiers and names without changing source grain

CREATE TABLE IF NOT EXISTS workspace.default.aisles (
  aisle_id INT,
  aisle STRING
)
USING DELTA
COMMENT 'validated and standardized instacart aisles';

INSERT OVERWRITE TABLE workspace.default.aisles
SELECT
  CAST(aisle_id AS INT) AS aisle_id,
  trim(aisle) AS aisle
FROM workspace.default.aisles;
