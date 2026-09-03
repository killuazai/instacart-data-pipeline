# Validation Documentation

**Engineer Instacart — Data Quality and Validation Checks**

---

## Validation Philosophy

Validation is **part of the pipeline** and should be completed before moving downstream. Each layer validates its inputs and outputs to ensure data quality propagates through the medallion architecture.

**Key Principles:**
* **Fail Fast**: Detect issues at the earliest layer possible
* **Record Evidence**: Log all validation results with timestamps
* **Automated Checks**: Build validation into pipeline code, not manual inspection
* **Reconciliation**: Every downstream row must trace back to source
* **Business Rules**: Validate not just technical integrity but business logic

---

## 1. Bronze Validation

### Purpose
Validate raw ingestion from source CSV files into Bronze Delta tables.

### Critical Checks

#### 1.1 Source vs Bronze Row Count Reconciliation

**What**: Confirm all source rows loaded into Bronze

**How**:
```sql
-- Count source CSV rows (via COPY INTO metrics or pre-load count)
SELECT COUNT(*) FROM text.`/path/to/orders.csv`;

-- Count Bronze table rows
SELECT COUNT(*) FROM instacart_bronze.orders;

-- Expected: counts match exactly
```

**Expected Results**:
* `orders.csv` → `bronze.orders`: 3,421,083 rows
* `products.csv` → `bronze.products`: 49,688 rows
* `aisles.csv` → `bronze.aisles`: 134 rows
* `departments.csv` → `bronze.departments`: 21 rows
* `order_products__prior.csv` → `bronze.order_products_prior`: ~32.4M rows
* `order_products__train.csv` → `bronze.order_products_train`: ~1.4M rows

**Validation Query**:
```sql
SELECT 
  'orders' AS table_name,
  (SELECT COUNT(*) FROM instacart_bronze.orders) AS bronze_count,
  3421083 AS expected_count,
  CASE WHEN (SELECT COUNT(*) FROM instacart_bronze.orders) = 3421083 
       THEN 'PASS' ELSE 'FAIL' END AS status

UNION ALL

SELECT 
  'products',
  (SELECT COUNT(*) FROM instacart_bronze.products),
  49688,
  CASE WHEN (SELECT COUNT(*) FROM instacart_bronze.products) = 49688 
       THEN 'PASS' ELSE 'FAIL' END

-- Repeat for all tables
```

---

#### 1.2 Null Required Identifiers

**What**: Ensure primary keys are never NULL

**How**:
```sql
-- Orders: order_id must not be NULL
SELECT COUNT(*) AS null_order_ids
FROM instacart_bronze.orders
WHERE order_id IS NULL;
-- Expected: 0

-- Products: product_id must not be NULL
SELECT COUNT(*) AS null_product_ids
FROM instacart_bronze.products
WHERE product_id IS NULL;
-- Expected: 0

-- Order Products: order_id AND product_id must not be NULL
SELECT COUNT(*) AS null_key_rows
FROM instacart_bronze.order_products_prior
WHERE order_id IS NULL OR product_id IS NULL;
-- Expected: 0
```

**Business Rule**: A transaction without identifiers cannot be processed.

---

#### 1.3 Duplicate Primary Keys

**What**: Ensure source data has no unexpected duplicates

**How**:
```sql
-- Orders: order_id should be unique
SELECT order_id, COUNT(*) AS duplicate_count
FROM instacart_bronze.orders
GROUP BY order_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- Products: product_id should be unique
SELECT product_id, COUNT(*) AS duplicate_count
FROM instacart_bronze.products
GROUP BY product_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows
```

**Business Rule**: Each order and product should appear once in reference data.

---

#### 1.4 Rescued / Malformed Rows

**What**: Check for parsing errors during CSV ingestion

**How**:
```sql
-- If using Auto Loader or COPY INTO with rescue columns
SELECT COUNT(*) AS malformed_rows
FROM instacart_bronze.orders
WHERE _rescued_data IS NOT NULL;
-- Expected: 0
```

**Action if Failed**: Investigate source file quality, adjust schema or parsing options.

---

#### 1.5 Expected Source Files Present

**What**: Confirm all required CSVs are available

**How**:
```python
# Check file existence in DBFS or Unity Catalog Volume
expected_files = [
    "orders.csv",
    "products.csv",
    "aisles.csv",
    "departments.csv",
    "order_products__prior.csv",
    "order_products__train.csv"
]

# Check if files exist (pseudo-code)
for file in expected_files:
    assert file_exists(f"/Volumes/instacart/raw/{file}"), f"Missing: {file}"
```

**Expected**: All 6 files present before ingestion starts.

---

## 2. Silver Validation

### Purpose
Validate cleaned, standardized, and joined data before dimensional modeling.

### Critical Checks

#### 2.1 Bronze vs Silver Row Preservation

**What**: Ensure no rows are silently dropped during cleaning/transformation

**How**:
```sql
-- Order Products: Bronze source rows should equal Silver rows
SELECT 
  (SELECT COUNT(*) FROM instacart_bronze.order_products_prior) + 
  (SELECT COUNT(*) FROM instacart_bronze.order_products_train) AS bronze_total,
  (SELECT COUNT(*) FROM instacart_silver.order_products) AS silver_total,
  CASE WHEN 
    (SELECT COUNT(*) FROM instacart_bronze.order_products_prior) + 
    (SELECT COUNT(*) FROM instacart_bronze.order_products_train) = 
    (SELECT COUNT(*) FROM instacart_silver.order_products)
  THEN 'PASS' ELSE 'FAIL' END AS reconciliation_status;
-- Expected: bronze_total = silver_total = 33,819,103
```

**Exception Handling**: If rows are intentionally filtered (e.g., invalid records), document the exclusion logic and count.

---

#### 2.2 Null Required Keys

**What**: Foreign keys must not be NULL in Silver (referential integrity preparation)

**How**:
```sql
-- Silver Order Products: Check foreign keys
SELECT 
  COUNT(*) AS total_rows,
  SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_ids,
  SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_ids,
  SUM(CASE WHEN user_id IS NULL THEN 1 ELSE 0 END) AS null_user_ids
FROM instacart_silver.order_products;
-- Expected: null counts = 0 for all columns
```

---

#### 2.3 Duplicate Keys and Grain Validation

**What**: Confirm grain integrity (one row per order-product combination)

**How**:
```sql
-- Silver Order Products: (order_id, product_id) should be unique
SELECT order_id, product_id, COUNT(*) AS duplicate_count
FROM instacart_silver.order_products
GROUP BY order_id, product_id
HAVING COUNT(*) > 1;
-- Expected: 0 rows (no duplicates)
```

**Business Rule**: A customer cannot add the same product twice in one order (or if they can, we need quantity field).

---

#### 2.4 Valid Ranges

**What**: Business logic constraints on numeric fields

**How**:
```sql
-- Order hour should be 0-23
SELECT COUNT(*) AS invalid_hours
FROM instacart_silver.orders
WHERE order_hour_of_day < 0 OR order_hour_of_day > 23;
-- Expected: 0

-- Order day of week should be 0-6
SELECT COUNT(*) AS invalid_dow
FROM instacart_silver.orders
WHERE order_dow < 0 OR order_dow > 6;
-- Expected: 0

-- Add to cart order should be >= 1
SELECT COUNT(*) AS invalid_cart_order
FROM instacart_silver.order_products
WHERE add_to_cart_order < 1;
-- Expected: 0

-- Reordered should be 0 or 1
SELECT COUNT(*) AS invalid_reorder_flag
FROM instacart_silver.order_products
WHERE reordered NOT IN (0, 1);
-- Expected: 0
```

---

#### 2.5 Valid `eval_set` Values

**What**: Source system identifier should be 'prior' or 'train'

**How**:
```sql
SELECT eval_set, COUNT(*) AS row_count
FROM instacart_silver.orders
GROUP BY eval_set;
-- Expected: Only 'prior' and 'train' values

SELECT COUNT(*) AS invalid_eval_set
FROM instacart_silver.orders
WHERE eval_set NOT IN ('prior', 'train');
-- Expected: 0
```

---

#### 2.6 Missing Relationships

**What**: Ensure all foreign keys have matching parent records

**How**:
```sql
-- Order Products → Orders: All order_ids should exist in orders table
SELECT COUNT(*) AS orphan_orders
FROM instacart_silver.order_products op
LEFT JOIN instacart_silver.orders o ON op.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Expected: 0

-- Order Products → Products: All product_ids should exist in products table
SELECT COUNT(*) AS orphan_products
FROM instacart_silver.order_products op
LEFT JOIN instacart_silver.products p ON op.product_id = p.product_id
WHERE p.product_id IS NULL;
-- Expected: 0

-- Products → Aisles
SELECT COUNT(*) AS orphan_aisles
FROM instacart_silver.products p
LEFT JOIN instacart_silver.aisles a ON p.aisle_id = a.aisle_id
WHERE a.aisle_id IS NULL;
-- Expected: 0

-- Products → Departments
SELECT COUNT(*) AS orphan_departments
FROM instacart_silver.products p
LEFT JOIN instacart_silver.departments d ON p.department_id = d.department_id
WHERE d.department_id IS NULL;
-- Expected: 0
```

**Business Rule**: All transactions must reference valid master data entities.

---

## 3. Gold Validation

### Purpose
Validate dimensional star schema integrity before consumption.

### Critical Checks

#### 3.1 Silver vs Gold Fact Row Reconciliation

**What**: Confirm all Silver order-product rows exist in Gold fact table

**How**:
```sql
SELECT 
  (SELECT COUNT(*) FROM instacart_silver.order_products) AS silver_count,
  (SELECT COUNT(*) FROM instacart_gold.fact_order_items) AS gold_count,
  (SELECT COUNT(*) FROM instacart_silver.order_products) - 
  (SELECT COUNT(*) FROM instacart_gold.fact_order_items) AS row_difference,
  CASE WHEN 
    (SELECT COUNT(*) FROM instacart_silver.order_products) = 
    (SELECT COUNT(*) FROM instacart_gold.fact_order_items)
  THEN 'PASS' ELSE 'FAIL' END AS reconciliation_status;
-- Expected: silver_count = gold_count = 33,819,103
```

---

#### 3.2 Dimension Key Uniqueness

**What**: Primary keys in dimensions must be unique

**How**:
```sql
-- dim_products: product_key should be unique
SELECT product_key, COUNT(*) AS duplicate_count
FROM instacart_gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- dim_customers: customer_key should be unique
SELECT customer_key, COUNT(*) AS duplicate_count
FROM instacart_gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- dim_orders: order_key should be unique
SELECT order_key, COUNT(*) AS duplicate_count
FROM instacart_gold.dim_orders
GROUP BY order_key
HAVING COUNT(*) > 1;
-- Expected: 0 rows
```

**Validation Summary**:
```sql
SELECT 
  'dim_products' AS dimension,
  COUNT(DISTINCT product_key) AS unique_keys,
  COUNT(*) AS total_rows,
  CASE WHEN COUNT(DISTINCT product_key) = COUNT(*) THEN 'PASS' ELSE 'FAIL' END AS status
FROM instacart_gold.dim_products

UNION ALL

SELECT 
  'dim_customers',
  COUNT(DISTINCT customer_key),
  COUNT(*),
  CASE WHEN COUNT(DISTINCT customer_key) = COUNT(*) THEN 'PASS' ELSE 'FAIL' END
FROM instacart_gold.dim_customers

UNION ALL

SELECT 
  'dim_orders',
  COUNT(DISTINCT order_key),
  COUNT(*),
  CASE WHEN COUNT(DISTINCT order_key) = COUNT(*) THEN 'PASS' ELSE 'FAIL' END
FROM instacart_gold.dim_orders;
```

---

#### 3.3 Fact Grain Uniqueness

**What**: Confirm fact table grain (one row per order-product)

**How**:
```sql
-- Option 1: Surrogate key should be unique
SELECT order_item_key, COUNT(*) AS duplicate_count
FROM instacart_gold.fact_order_items
GROUP BY order_item_key
HAVING COUNT(*) > 1;
-- Expected: 0 rows

-- Option 2: Natural key (order_key, product_key) should be unique
SELECT order_key, product_key, COUNT(*) AS duplicate_count
FROM instacart_gold.fact_order_items
GROUP BY order_key, product_key
HAVING COUNT(*) > 1;
-- Expected: 0 rows
```

---

#### 3.4 Null Foreign Keys

**What**: Fact table foreign keys must never be NULL

**How**:
```sql
SELECT 
  COUNT(*) AS total_rows,
  SUM(CASE WHEN order_key IS NULL THEN 1 ELSE 0 END) AS null_order_keys,
  SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS null_product_keys,
  SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS null_customer_keys,
  CASE WHEN 
    SUM(CASE WHEN order_key IS NULL THEN 1 ELSE 0 END) = 0 AND
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) = 0 AND
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) = 0
  THEN 'PASS' ELSE 'FAIL' END AS validation_status
FROM instacart_gold.fact_order_items;
-- Expected: all null counts = 0
```

---

#### 3.5 Unmatched Relationships (Referential Integrity)

**What**: All fact foreign keys must have matching dimension records

**How**:
```sql
-- Fact → dim_products
SELECT COUNT(*) AS orphan_product_keys
FROM instacart_gold.fact_order_items f
LEFT JOIN instacart_gold.dim_products p ON f.product_key = p.product_key
WHERE p.product_key IS NULL;
-- Expected: 0

-- Fact → dim_orders
SELECT COUNT(*) AS orphan_order_keys
FROM instacart_gold.fact_order_items f
LEFT JOIN instacart_gold.dim_orders o ON f.order_key = o.order_key
WHERE o.order_key IS NULL;
-- Expected: 0

-- Fact → dim_customers
SELECT COUNT(*) AS orphan_customer_keys
FROM instacart_gold.fact_order_items f
LEFT JOIN instacart_gold.dim_customers c ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;
-- Expected: 0
```

**Validation Summary**:
```sql
SELECT 
  'fact -> dim_products' AS relationship,
  (SELECT COUNT(*) FROM instacart_gold.fact_order_items f
   LEFT JOIN instacart_gold.dim_products p ON f.product_key = p.product_key
   WHERE p.product_key IS NULL) AS orphan_count,
  CASE WHEN (SELECT COUNT(*) FROM instacart_gold.fact_order_items f
             LEFT JOIN instacart_gold.dim_products p ON f.product_key = p.product_key
             WHERE p.product_key IS NULL) = 0 
       THEN 'PASS' ELSE 'FAIL' END AS status

UNION ALL

SELECT 
  'fact -> dim_orders',
  (SELECT COUNT(*) FROM instacart_gold.fact_order_items f
   LEFT JOIN instacart_gold.dim_orders o ON f.order_key = o.order_key
   WHERE o.order_key IS NULL),
  CASE WHEN (SELECT COUNT(*) FROM instacart_gold.fact_order_items f
             LEFT JOIN instacart_gold.dim_orders o ON f.order_key = o.order_key
             WHERE o.order_key IS NULL) = 0 
       THEN 'PASS' ELSE 'FAIL' END

UNION ALL

SELECT 
  'fact -> dim_customers',
  (SELECT COUNT(*) FROM instacart_gold.fact_order_items f
   LEFT JOIN instacart_gold.dim_customers c ON f.customer_key = c.customer_key
   WHERE c.customer_key IS NULL),
  CASE WHEN (SELECT COUNT(*) FROM instacart_gold.fact_order_items f
             LEFT JOIN instacart_gold.dim_customers c ON f.customer_key = c.customer_key
             WHERE c.customer_key IS NULL) = 0 
       THEN 'PASS' ELSE 'FAIL' END;
```

---

#### 3.6 Measure Reconciliation

**What**: Validate that measures in fact table match source aggregations

**How**:
```sql
-- Total products purchased should match across layers
SELECT 
  'Silver' AS layer,
  COUNT(*) AS total_products_purchased
FROM instacart_silver.order_products

UNION ALL

SELECT 
  'Gold (Fact)',
  COUNT(*)
FROM instacart_gold.fact_order_items;
-- Expected: counts match

-- Reorder count reconciliation
SELECT 
  SUM(CAST(reordered AS INT)) AS silver_reorder_count
FROM instacart_silver.order_products;

SELECT 
  SUM(CAST(is_reordered AS INT)) AS gold_reorder_count
FROM instacart_gold.fact_order_items;
-- Expected: counts match
```

---

#### 3.7 Pre-Aggregated Dimension Metrics

**What**: Validate customer metrics in dim_customers

**How**:
```sql
-- Sample validation: Check a specific customer's total_orders
WITH customer_orders AS (
  SELECT 
    o.user_id,
    MAX(o.order_number) AS calculated_total_orders,
    COUNT(DISTINCT o.order_id) AS calculated_order_count
  FROM instacart_gold.dim_orders o
  GROUP BY o.user_id
)
SELECT 
  c.customer_key,
  c.total_orders AS dimension_total_orders,
  co.calculated_total_orders,
  c.total_order_count AS dimension_order_count,
  co.calculated_order_count,
  CASE WHEN 
    c.total_orders = co.calculated_total_orders AND
    c.total_order_count = co.calculated_order_count
  THEN 'PASS' ELSE 'FAIL' END AS validation_status
FROM instacart_gold.dim_customers c
JOIN customer_orders co ON c.customer_key = co.user_id
WHERE c.customer_key IN (1, 2, 100, 1000) -- Sample customers
ORDER BY c.customer_key;
```

---

#### 3.8 Temporal Attribute Derivation

**What**: Validate derived columns in dim_orders

**How**:
```sql
-- Check day_of_week_name matches order_dow
SELECT 
  order_dow,
  day_of_week_name,
  COUNT(*) AS row_count
FROM instacart_gold.dim_orders
GROUP BY order_dow, day_of_week_name
ORDER BY order_dow;
-- Expected: 
-- 0 -> 'Sunday'
-- 1 -> 'Monday'
-- 2 -> 'Tuesday'
-- 3 -> 'Wednesday'
-- 4 -> 'Thursday'
-- 5 -> 'Friday'
-- 6 -> 'Saturday'

-- Check time_of_day_bucket matches order_hour_of_day
SELECT 
  time_of_day_bucket,
  MIN(order_hour_of_day) AS min_hour,
  MAX(order_hour_of_day) AS max_hour
FROM instacart_gold.dim_orders
GROUP BY time_of_day_bucket;
-- Expected:
-- 'Morning' -> 5-11
-- 'Afternoon' -> 12-16
-- 'Evening' -> 17-21
-- 'Night' -> 22-4 (0-4, 22-23)
```

---

## 4. Business Question Validation

### Purpose
For every dashboard query, write the reconciliation or reasonableness check used to confirm the result.

---

### BQ1: Which products and departments are purchased most frequently?

**Query Validation**:
```sql
-- Total purchases should equal fact table row count
SELECT SUM(total_orders) AS sum_of_product_totals
FROM (
  SELECT 
    p.product_name,
    COUNT(*) AS total_orders
  FROM instacart_gold.fact_order_items f
  JOIN instacart_gold.dim_products p ON f.product_key = p.product_key
  GROUP BY p.product_name
);
-- Expected: 33,819,103 (matches fact table row count)
```

**Reasonableness Checks**:
* Top product should be high-frequency item (e.g., bananas, milk)
* Top department should be produce or dairy
* Reorder rate should be 40-85% for top products

**Sample Validation**:
```sql
-- Check that Bananas (product_id 24852) is in top 10
SELECT 
  p.product_name,
  COUNT(*) AS total_purchases,
  RANK() OVER (ORDER BY COUNT(*) DESC) AS product_rank
FROM instacart_gold.fact_order_items f
JOIN instacart_gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
HAVING p.product_name = 'Banana';
-- Expected: rank <= 10
```

---

### BQ2: How does purchasing behavior change by day and hour?

**Query Validation**:
```sql
-- Total orders across all days/hours should equal distinct orders in fact
SELECT 
  SUM(total_orders) AS sum_across_time_buckets
FROM (
  SELECT 
    o.day_of_week_name,
    o.order_hour_of_day,
    COUNT(DISTINCT f.order_key) AS total_orders
  FROM instacart_gold.fact_order_items f
  JOIN instacart_gold.dim_orders o ON f.order_key = o.order_key
  GROUP BY o.day_of_week_name, o.order_hour_of_day
);
-- Expected: 3,346,083 (total distinct orders)
```

**Reasonableness Checks**:
* Peak day should be Sunday (weekend shopping)
* Peak hours should be 10-11 AM and 2-3 PM (lunch/afternoon)
* Lowest activity: 2-5 AM

**Sample Validation**:
```sql
-- Confirm Sunday has most orders
SELECT 
  day_of_week_name,
  COUNT(DISTINCT order_key) AS order_count,
  RANK() OVER (ORDER BY COUNT(DISTINCT order_key) DESC) AS day_rank
FROM instacart_gold.fact_order_items f
JOIN instacart_gold.dim_orders o ON f.order_key = o.order_key
GROUP BY day_of_week_name
ORDER BY order_count DESC;
-- Expected: 'Sunday' has rank = 1
```

---

### BQ3: Which products have the highest reorder behavior?

**Query Validation**:
```sql
-- Reorder rate should be between 0% and 100%
SELECT 
  p.product_name,
  ROUND(SUM(CAST(f.is_reordered AS INT)) * 100.0 / COUNT(*), 2) AS reorder_rate_pct
FROM instacart_gold.fact_order_items f
JOIN instacart_gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
HAVING COUNT(*) >= 100
ORDER BY reorder_rate_pct DESC
LIMIT 10;
-- Expected: All reorder_rate_pct values between 0 and 100
```

**Reasonableness Checks**:
* Staples (bananas, milk, eggs) should have high reorder rates (70-85%)
* Specialty items should have lower reorder rates (20-40%)
* Average reorder rate across all products should be ~59% [TO CONFIRM]

**Sample Validation**:
```sql
-- Global reorder rate
SELECT 
  SUM(CAST(is_reordered AS INT)) AS total_reorders,
  COUNT(*) AS total_purchases,
  ROUND(SUM(CAST(is_reordered AS INT)) * 100.0 / COUNT(*), 2) AS global_reorder_rate
FROM instacart_gold.fact_order_items;
-- Expected: ~59% reorder rate
```

---

### BQ4: What are the most common product pairs?

**Query Validation**:
```sql
-- Validate that product pairs are truly co-occurring in same orders
WITH product_pairs AS (
  SELECT 
    f1.order_key,
    f1.product_key AS product_1_key,
    f2.product_key AS product_2_key
  FROM instacart_gold.fact_order_items f1
  JOIN instacart_gold.fact_order_items f2 ON f1.order_key = f2.order_key
    AND f1.product_key < f2.product_key
  LIMIT 1000
)
SELECT 
  pp.order_key,
  pp.product_1_key,
  pp.product_2_key,
  COUNT(DISTINCT f1.order_item_key) AS product_1_found,
  COUNT(DISTINCT f2.order_item_key) AS product_2_found
FROM product_pairs pp
JOIN instacart_gold.fact_order_items f1 
  ON pp.order_key = f1.order_key AND pp.product_1_key = f1.product_key
JOIN instacart_gold.fact_order_items f2 
  ON pp.order_key = f2.order_key AND pp.product_2_key = f2.product_key
GROUP BY pp.order_key, pp.product_1_key, pp.product_2_key
HAVING product_1_found = 0 OR product_2_found = 0;
-- Expected: 0 rows (all pairs should have both products in the order)
```

**Reasonableness Checks**:
* Top pairs should be complementary items (e.g., bananas + strawberries, milk + eggs)
* Pairs should come from same department or related categories
* Minimum occurrence threshold (e.g., 100 orders) filters noise

---

## 5. Pre-Aggregated Analytics Tables (Gold Layer)

### gold_product_summary

**Validation**:
```sql
-- Row count should equal number of distinct products
SELECT 
  (SELECT COUNT(*) FROM instacart_gold.gold_product_summary) AS summary_count,
  (SELECT COUNT(DISTINCT product_key) FROM instacart_gold.fact_order_items) AS fact_distinct_products,
  CASE WHEN 
    (SELECT COUNT(*) FROM instacart_gold.gold_product_summary) = 
    (SELECT COUNT(DISTINCT product_key) FROM instacart_gold.fact_order_items)
  THEN 'PASS' ELSE 'FAIL' END AS validation_status;
```

### gold_customer_behavior

**Validation**:
```sql
-- Row count should equal number of distinct customers
SELECT 
  (SELECT COUNT(*) FROM instacart_gold.gold_customer_behavior) AS summary_count,
  (SELECT COUNT(DISTINCT customer_key) FROM instacart_gold.fact_order_items) AS fact_distinct_customers,
  CASE WHEN 
    (SELECT COUNT(*) FROM instacart_gold.gold_customer_behavior) = 
    (SELECT COUNT(DISTINCT customer_key) FROM instacart_gold.fact_order_items)
  THEN 'PASS' ELSE 'FAIL' END AS validation_status;
```

### gold_temporal_patterns

**Validation**:
```sql
-- Row count should equal 7 days * 24 hours = 168 combinations
SELECT 
  COUNT(*) AS temporal_combinations,
  CASE WHEN COUNT(*) = 168 THEN 'PASS' ELSE 'FAIL' END AS validation_status
FROM instacart_gold.gold_temporal_patterns;
```

---

## 6. Validation Evidence Log

### 6.1 Bronze Layer Validation

| Layer / Query | Check | Expected | Actual | Status | Owner | Date |
|---|---|---|---|---|---|---|
| Bronze / orders | Row count vs source | 3,421,083 | [TBD] | PENDING | Tina | [TBD] |
| Bronze / products | Row count vs source | 49,688 | [TBD] | PENDING | Tina | [TBD] |
| Bronze / order_products_prior | Row count vs source | ~32.4M | [TBD] | PENDING | Tina | [TBD] |
| Bronze / order_products_train | Row count vs source | ~1.4M | [TBD] | PENDING | Tina | [TBD] |
| Bronze / orders | Null order_id | 0 | [TBD] | PENDING | Tina | [TBD] |
| Bronze / products | Null product_id | 0 | [TBD] | PENDING | Tina | [TBD] |
| Bronze / orders | Duplicate order_id | 0 | [TBD] | PENDING | Tina | [TBD] |
| Bronze / products | Duplicate product_id | 0 | [TBD] | PENDING | Tina | [TBD] |
| Bronze / all tables | Malformed rows (_rescued_data) | 0 | [TBD] | PENDING | Tina | [TBD] |

---

### 6.2 Silver Layer Validation

| Layer / Query | Check | Expected | Actual | Status | Owner | Date |
|---|---|---|---|---|---|---|
| Silver / order_products | Bronze → Silver row count | 33,819,103 | [TBD] | PENDING | Tina | [TBD] |
| Silver / order_products | Null foreign keys | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / order_products | Duplicate (order_id, product_id) | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / orders | Invalid order_hour_of_day | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / orders | Invalid order_dow | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / order_products | Invalid add_to_cart_order | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / order_products | Invalid reordered flag | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / orders | Invalid eval_set values | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / order_products | Orphan orders (missing in orders table) | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / order_products | Orphan products (missing in products table) | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / products | Orphan aisles | 0 | [TBD] | PENDING | Tina | [TBD] |
| Silver / products | Orphan departments | 0 | [TBD] | PENDING | Tina | [TBD] |

---

### 6.3 Gold Layer Validation

| Layer / Query | Check | Expected | Actual | Status | Owner | Date |
|---|---|---|---|---|---|---|
| Gold / fact_order_items | Silver → Gold row count | 33,819,103 | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_products | Duplicate product_key | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_customers | Duplicate customer_key | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_orders | Duplicate order_key | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_products | Primary key count | 49,687 | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_customers | Primary key count | 206,209 | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_orders | Primary key count | 3,346,083 | [TBD] | PENDING | Tina | [TBD] |
| Gold / fact_order_items | Duplicate order_item_key | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / fact_order_items | Duplicate (order_key, product_key) | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / fact_order_items | Null foreign keys | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / fact → dim_products | Orphan product_key | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / fact → dim_orders | Orphan order_key | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / fact → dim_customers | Orphan customer_key | 0 | [TBD] | PENDING | Tina | [TBD] |
| Gold / fact_order_items | Total reorder count matches Silver | [TBD] | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_customers | Pre-aggregated total_orders accuracy | Sample match | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_orders | day_of_week_name derivation | Correct mapping | [TBD] | PENDING | Tina | [TBD] |
| Gold / dim_orders | time_of_day_bucket derivation | Correct ranges | [TBD] | PENDING | Tina | [TBD] |
| Gold / gold_product_summary | Row count vs fact distinct products | Match | [TBD] | PENDING | Tina | [TBD] |
| Gold / gold_customer_behavior | Row count vs fact distinct customers | Match | [TBD] | PENDING | Tina | [TBD] |
| Gold / gold_temporal_patterns | Row count (days * hours) | 168 | [TBD] | PENDING | Tina | [TBD] |

---

### 6.4 Business Question Validation

| Business Question | Check | Expected | Actual | Status | Owner | Date |
|---|---|---|---|---|---|---|
| BQ1 | Sum of product totals = fact row count | 33,819,103 | [TBD] | PENDING | Tina | [TBD] |
| BQ1 | Top product is high-frequency staple | Yes | [TBD] | PENDING | Tina | [TBD] |
| BQ1 | 'Banana' in top 10 products | Rank ≤ 10 | [TBD] | PENDING | Tina | [TBD] |
| BQ2 | Sum of orders by time = total orders | 3,346,083 | [TBD] | PENDING | Tina | [TBD] |
| BQ2 | Peak day is Sunday | Rank = 1 | [TBD] | PENDING | Tina | [TBD] |
| BQ2 | Peak hours are 10-11 AM, 2-3 PM | Yes | [TBD] | PENDING | Tina | [TBD] |
| BQ3 | Reorder rates between 0-100% | Yes | [TBD] | PENDING | Tina | [TBD] |
| BQ3 | Global reorder rate ~59% | ~59% | [TBD] | PENDING | Tina | [TBD] |
| BQ3 | Staples (bananas, milk) have high reorder | 70-85% | [TBD] | PENDING | Tina | [TBD] |
| BQ4 | Product pairs exist in same orders | All valid | [TBD] | PENDING | Tina | [TBD] |
| BQ4 | Top pairs are complementary items | Yes | [TBD] | PENDING | Tina | [TBD] |

---

## 7. Validation Automation

### Recommended Approach

**Option 1: Great Expectations**
```python
import great_expectations as gx

# Define expectations for fact_order_items
expectations = [
    gx.expect_column_values_to_not_be_null(column="order_key"),
    gx.expect_column_values_to_not_be_null(column="product_key"),
    gx.expect_column_values_to_be_between(column="add_to_cart_order", min_value=1),
    gx.expect_column_values_to_be_in_set(column="is_reordered", value_set=[0, 1])
]
```

**Option 2: Delta Live Tables Expectations**
```python
@dlt.table(
  name="fact_order_items",
  expect_or_fail={
    "valid_order_key": "order_key IS NOT NULL",
    "valid_product_key": "product_key IS NOT NULL",
    "valid_reorder_flag": "is_reordered IN (0, 1)"
  }
)
def create_fact_order_items():
    return spark.table("instacart_silver.order_products")
```

**Option 3: Custom Validation Notebook**
* Create `notebooks/validation/run_all_checks.py`
* Execute all validation queries
* Write results to `instacart_gold.validation_log` table
* Alert on failures via email/Slack

---

## 8. Validation Best Practices

1. **Run validation after each layer transformation**
   * Bronze validation → before Silver ingestion
   * Silver validation → before Gold transformation
   * Gold validation → before dashboard refresh

2. **Log validation results to a table**
   * Track validation history over time
   * Identify patterns in data quality issues
   * Audit trail for compliance

3. **Set up alerting for validation failures**
   * Email/Slack notification on critical failures
   * Stop pipeline on referential integrity violations
   * Continue with warnings for minor issues

4. **Document exceptions**
   * If a validation check fails, document WHY
   * Add exclusion logic if intentional
   * Update expected values if business rules change

5. **Version control validation queries**
   * Store validation SQL in `notebooks/validation/` folder
   * Track changes to validation logic
   * Reuse validation queries across pipeline runs

---

**Last Updated**: September 2, 2026  
**Document Owner**: Tina (Cristina)  
**Project**: Engineer Instacart  
**Next Review**: [After first pipeline run]
