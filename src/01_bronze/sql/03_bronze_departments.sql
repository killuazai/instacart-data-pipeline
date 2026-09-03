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


