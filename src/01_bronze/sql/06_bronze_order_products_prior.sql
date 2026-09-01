-- saved-query name: 06_bronze_order_products_prior
-- paste the approved Databricks SQL for this task below
-- TABLE: order_products__prior
CREATE OR REPLACE TABLE order_products__prior AS
SELECT * FROM read_files(
  '/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/order_products__prior.csv',
  format => 'csv', header => true,
  schema => 'order_id INT,product_id INT,add_to_cart_order INT,reordered INT'
);

DESCRIBE TABLE order_products__prior;

SELECT * 
FROM order_products__prior;