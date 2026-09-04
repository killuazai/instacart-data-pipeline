# Validation Documentation

**Instacart Data Pipeline — Data Quality and Validation Checks**

---

## Validation Philosophy

Validation is **part of the pipeline** and should be completed before moving downstream. Each layer validates its inputs and outputs to ensure data quality propagates through the medallion architecture.

**Key Principles:**
* **Fail Fast**: Detect issues at the earliest layer possible
* **Consolidated Validation**: One query per layer produces table-level PASS/REVIEW status
* **Automated Checks**: Build validation into pipeline code, not manual inspection
* **Reconciliation**: Track row differences between layers with documented drops
* **Business Rules**: Validate not just technical integrity but business logic

**Validation Status:**
* **PASS**: All checks clean for that table (no nulls, no duplicates, no orphans, no required field issues)
* **REVIEW**: One or more issues detected; investigate before proceeding

**Row Difference Philosophy:**  
Silver intentionally drops rows (null keys, invalid ranges, orphan FKs). A non-zero `row_difference` vs Bronze is **expected**, not a failure. Status checks whether problems remain in the clean output after documented drops.

---

## 1. Bronze Validation

### Purpose
Validate raw ingestion from source CSV files into Bronze Delta tables.

### Schema
`workspace.instacart_bronze`

### Tables Created
* `orders` - 3,421,083 rows
* `products` - 49,688 rows
* `aisles` - 134 rows
* `departments` - 21 rows
* `order_products_prior` - ~32.4M rows
* `order_products_train` - ~1.4M rows

### Validation Checks

Bronze validation confirms:
1. All source CSV rows loaded successfully
2. No parsing errors or malformed rows
3. Primary keys are present and unique
4. All expected source files were present

**Individual Table Validation Pattern:**
```sql
-- Validate orders table
SELECT 
  'orders' AS table_name,
  COUNT(*) AS bronze_count,
  3421083 AS expected_count,
  SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_keys,
  CASE 
    WHEN COUNT(*) = 3421083 
      AND SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) = 0
    THEN 'PASS' 
    ELSE 'REVIEW' 
  END AS status
FROM workspace.instacart_bronze.orders;

-- Repeat similar pattern for products, aisles, departments, order_products_prior, order_products_train
```

**Expected Result**: All tables return status = 'PASS'

---

## 2. Silver Validation

### Purpose
Validate cleaned, standardized data with referential integrity before dimensional modeling.

### Schema
`workspace.instacart_silver`

### Tables Created (with `_clean` suffix)
* `aisles_clean` - 134 rows
* `departments_clean` - 21 rows
* `products_clean` - ~49,687 rows (drops products with orphan FK to aisles/departments)
* `orders_clean` - ~3,421,083 rows (drops rows with invalid day/hour ranges)
* `order_products_clean` - ~33.8M rows (union of prior + train, drops orphan FK to orders)

### Build Order & Dependencies

| # | Task | Depends on | Why |
|---|------|------------|-----|
| 1 | `aisles_clean` | Bronze aisles | Independent |
| 2 | `departments_clean` | Bronze departments | Independent |
| 3 | `products_clean` | `aisles_clean`, `departments_clean` | Checks EXISTS against cleaned lookups |
| 4 | `orders_clean` | Bronze orders | Independent |
| 5 | `order_products_clean` | `orders_clean` | Checks EXISTS against cleaned orders |
| 6 | Silver validation | All 5 above | Consolidated PASS/REVIEW gate |

### Consolidated Validation Query

**Owner**: Ina  
**Name**: 14 - Silver Validation  
**Purpose**: Validate Silver row counts, required identifiers, candidate keys, required fields, referential integrity, and text-quality artifacts with table-level pass or fail results.  
**Grain**: One validation summary row per Silver table.

```sql
WITH validation AS (

    SELECT
        'aisles' AS table_name,
        (SELECT COUNT(*) FROM workspace.instacart_bronze.aisles) AS raw_rows,
        COUNT(*) AS clean_rows,
        COUNT(*) - (SELECT COUNT(*) FROM workspace.instacart_bronze.aisles) AS row_difference,
        SUM(CASE WHEN aisle_id IS NULL THEN 1 ELSE 0 END) AS null_key_rows,
        (SELECT COUNT(*) FROM (
            SELECT aisle_id FROM aisles_clean
            WHERE aisle_id IS NOT NULL GROUP BY aisle_id HAVING COUNT(*) > 1
        )) AS duplicate_keys,
        SUM(CASE WHEN aisle IS NULL OR TRIM(aisle) = '' THEN 1 ELSE 0 END) AS required_field_issues,
        0 AS unmatched_fk_rows
    FROM aisles_clean

    UNION ALL

    SELECT
        'departments',
        (SELECT COUNT(*) FROM workspace.instacart_bronze.departments),
        COUNT(*),
        COUNT(*) - (SELECT COUNT(*) FROM workspace.instacart_bronze.departments),
        SUM(CASE WHEN department_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT department_id FROM departments_clean
            WHERE department_id IS NOT NULL GROUP BY department_id HAVING COUNT(*) > 1
        )),
        SUM(CASE WHEN department IS NULL OR TRIM(department) = '' THEN 1 ELSE 0 END),
        0
    FROM departments_clean

    UNION ALL

    SELECT
        'products',
        (SELECT COUNT(*) FROM workspace.instacart_bronze.products),
        COUNT(*),
        COUNT(*) - (SELECT COUNT(*) FROM workspace.instacart_bronze.products),
        SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM products_clean
            WHERE product_id IS NOT NULL GROUP BY product_id HAVING COUNT(*) > 1
        )),
        SUM(CASE WHEN product_name IS NULL OR TRIM(product_name) = '' THEN 1 ELSE 0 END)
         + SUM(CASE WHEN INSTR(product_name, CHR(92)) > 0 THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM products_clean p
            LEFT JOIN aisles_clean a ON p.aisle_id = a.aisle_id
            WHERE p.aisle_id IS NOT NULL AND a.aisle_id IS NULL)
         + (SELECT COUNT(*) FROM products_clean p
            LEFT JOIN departments_clean d ON p.department_id = d.department_id
            WHERE p.department_id IS NOT NULL AND d.department_id IS NULL)
    FROM products_clean

    UNION ALL

    SELECT
        'orders',
        (SELECT COUNT(*) FROM workspace.instacart_bronze.orders),
        COUNT(*),
        COUNT(*) - (SELECT COUNT(*) FROM workspace.instacart_bronze.orders),
        SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id FROM orders_clean
            WHERE order_id IS NOT NULL GROUP BY order_id HAVING COUNT(*) > 1
        )),
        SUM(CASE
            WHEN user_id IS NULL
              OR order_number IS NULL
              OR order_dow NOT BETWEEN 0 AND 6
              OR order_hour_of_day NOT BETWEEN 0 AND 23
              OR (order_number = 1 AND days_since_prior_order IS NOT NULL)
              OR (order_number > 1 AND days_since_prior_order IS NULL)
            THEN 1
            ELSE 0
        END),
        0
    FROM orders_clean

    UNION ALL

    SELECT
        'order_products',
        (SELECT COUNT(*) FROM workspace.instacart_bronze.order_products_prior)
          + (SELECT COUNT(*) FROM workspace.instacart_bronze.order_products_train),
        COUNT(*),
        COUNT(*) - (
            (SELECT COUNT(*) FROM workspace.instacart_bronze.order_products_prior)
          + (SELECT COUNT(*) FROM workspace.instacart_bronze.order_products_train)
        ),
        SUM(CASE WHEN order_id IS NULL OR product_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id, product_id FROM order_products_clean
            GROUP BY order_id, product_id HAVING COUNT(*) > 1
        )),
        SUM(CASE
            WHEN add_to_cart_order IS NULL OR add_to_cart_order <= 0
            THEN 1 ELSE 0
        END),
        (SELECT COUNT(*) FROM order_products_clean op
            LEFT JOIN orders_clean o ON op.order_id = o.order_id
            WHERE o.order_id IS NULL)
         + (SELECT COUNT(*) FROM order_products_clean op
            LEFT JOIN products_clean p ON op.product_id = p.product_id
            WHERE p.product_id IS NULL)
    FROM order_products_clean

)

SELECT
    *,
    CASE
        WHEN null_key_rows = 0
             AND duplicate_keys = 0
             AND required_field_issues = 0
             AND unmatched_fk_rows = 0
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS status
FROM validation
ORDER BY table_name;
```

### Validation Output Columns

| Column | Meaning |
|--------|---------|
| `table_name` | Silver table being validated |
| `raw_rows` | Count from Bronze source |
| `clean_rows` | Count in Silver table |
| `row_difference` | clean_rows - raw_rows (negative = intentional drops) |
| `null_key_rows` | Rows with NULL primary/composite keys |
| `duplicate_keys` | Groups with duplicate keys |
| `required_field_issues` | Rows with NULL/empty required fields or text artifacts |
| `unmatched_fk_rows` | Rows with foreign keys that don't resolve |
| `status` | PASS (all checks = 0) or REVIEW |

### Expected Results

**All 5 tables should return status = 'PASS'**

| Table | Expected Behavior |
|-------|-------------------|
| `aisles` | Simple trim/casing, no dependencies |
| `departments` | Simple trim/casing, no dependencies |
| `products` | Depends on aisles + departments; backslash fix applied |
| `orders` | NULL `days_since_prior_order` preserved intentionally for first orders |
| `order_products` | Depends on orders; unions prior + train |

**Note on `row_difference`:**
- Shown per table but does NOT affect status
- Silver intentionally drops invalid rows
- See `decisions.md` for exclusion logic

**Note on `required_field_issues` for products:**
- Also counts any remaining backslash matches `CHR(92)` in `product_name`
- A regression in the backslash fix surfaces as REVIEW automatically

---

## 3. Gold Validation

### Purpose
Validate dimensional star schema integrity before consumption.

### Schema
`workspace.instacart_gold`

### Tables Created
* `gold_dim_product` - Product dimension with flattened aisle/department names
* `gold_dim_order` - Order dimension with customer, time, and interval context
* `gold_fact_order_product` - Narrow product-line fact table

### Three-Stage Validation

Gold uses three separate validation queries executed in sequence.

---

#### Query 18: Pre-Constraint Validation (Dimensions Only)

**Owner**: Cath  
**Purpose**: Validate dimension tables before building the fact table  
**Grain**: One validation summary row per dimension table

```sql
WITH validation AS (

    SELECT
        'gold_dim_product' AS table_name,
        COUNT(*) AS row_count,
        SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_key_rows,
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM gold_dim_product
            WHERE product_id IS NOT NULL GROUP BY product_id HAVING COUNT(*) > 1
        )) AS duplicate_keys,
        SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS required_field_issues
    FROM gold_dim_product

    UNION ALL

    SELECT
        'gold_dim_order',
        COUNT(*),
        SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id FROM gold_dim_order
            WHERE order_id IS NOT NULL GROUP BY order_id HAVING COUNT(*) > 1
        )),
        SUM(CASE WHEN user_id IS NULL OR order_number IS NULL THEN 1 ELSE 0 END)
    FROM gold_dim_order

)
SELECT
    table_name,
    row_count,
    null_key_rows,
    duplicate_keys,
    required_field_issues,
    CASE
        WHEN null_key_rows > 0 OR duplicate_keys > 0 OR required_field_issues > 0
        THEN 'REVIEW'
        ELSE 'PASS'
    END AS status
FROM validation
ORDER BY table_name;
```

**Expected**: 2 PASS rows with zero issue counts

---

#### Query 19: Constraint Checks (PK/FK Integrity)

**Owner**: Cath  
**Purpose**: Validate PK/FK constraints across all gold tables  
**Grain**: One validation summary row per constraint check

Produces **8 report rows** covering:
1. Product-key uniqueness
2. Order-key uniqueness
3. Fact (order_id, product_id) uniqueness
4. Null product keys
5. Null order keys
6. Null fact order/product keys
7. Fact-to-order relationship integrity
8. Fact-to-product relationship integrity

```sql
WITH constraint_checks AS (

    -- Check 1: gold_dim_product PK uniqueness
    SELECT
        'PK: gold_dim_product.product_id' AS constraint_name,
        'Primary Key Uniqueness' AS constraint_type,
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM gold_dim_product
            WHERE product_id IS NOT NULL
            GROUP BY product_id HAVING COUNT(*) > 1
        )) AS violations

    UNION ALL

    -- Check 2: gold_dim_order PK uniqueness
    SELECT
        'PK: gold_dim_order.order_id',
        'Primary Key Uniqueness',
        (SELECT COUNT(*) FROM (
            SELECT order_id FROM gold_dim_order
            WHERE order_id IS NOT NULL
            GROUP BY order_id HAVING COUNT(*) > 1
        ))

    UNION ALL

    -- Check 3: gold_fact_order_product composite PK uniqueness
    SELECT
        'PK: gold_fact_order_product (order_id, product_id)',
        'Composite Key Uniqueness',
        (SELECT COUNT(*) FROM (
            SELECT order_id, product_id FROM gold_fact_order_product
            WHERE order_id IS NOT NULL AND product_id IS NOT NULL
            GROUP BY order_id, product_id HAVING COUNT(*) > 1
        ))

    UNION ALL

    -- Check 4: gold_dim_product PK null check
    SELECT
        'PK: gold_dim_product.product_id NOT NULL',
        'Primary Key Null Check',
        (SELECT COUNT(*) FROM gold_dim_product WHERE product_id IS NULL)

    UNION ALL

    -- Check 5: gold_dim_order PK null check
    SELECT
        'PK: gold_dim_order.order_id NOT NULL',
        'Primary Key Null Check',
        (SELECT COUNT(*) FROM gold_dim_order WHERE order_id IS NULL)

    UNION ALL

    -- Check 6: gold_fact_order_product composite PK null check
    SELECT
        'PK: gold_fact_order_product (order_id, product_id) NOT NULL',
        'Composite Key Null Check',
        (SELECT COUNT(*) FROM gold_fact_order_product
         WHERE order_id IS NULL OR product_id IS NULL)

    UNION ALL

    -- Check 7: FK gold_fact_order_product.order_id → gold_dim_order.order_id
    SELECT
        'FK: gold_fact_order_product.order_id → gold_dim_order.order_id',
        'Foreign Key Integrity',
        (SELECT COUNT(*) FROM gold_fact_order_product f
         LEFT JOIN gold_dim_order d ON f.order_id = d.order_id
         WHERE f.order_id IS NOT NULL AND d.order_id IS NULL)

    UNION ALL

    -- Check 8: FK gold_fact_order_product.product_id → gold_dim_product.product_id
    SELECT
        'FK: gold_fact_order_product.product_id → gold_dim_product.product_id',
        'Foreign Key Integrity',
        (SELECT COUNT(*) FROM gold_fact_order_product f
         LEFT JOIN gold_dim_product d ON f.product_id = d.product_id
         WHERE f.product_id IS NOT NULL AND d.product_id IS NULL)

)
SELECT
    constraint_name,
    constraint_type,
    violations,
    CASE WHEN violations = 0 THEN 'PASS' ELSE 'REVIEW' END AS status
FROM constraint_checks
ORDER BY constraint_type, constraint_name;
```

**Expected**: 8 PASS rows with zero violations

**Note**: This query only checks the data. It does NOT execute `ALTER TABLE ... ADD CONSTRAINT` or register primary/foreign keys in Unity Catalog.

---

#### Query 20: Final Validation (Comprehensive)

**Owner**: Cath  
**Purpose**: Comprehensive gold validation - keys, integrity, silver-to-gold reconciliation, and measures  
**Returns**: Two result sets

**Result Set 1: Table-Level Checks**

```sql
-- PART 1: Table-level validation (keys, row counts, referential integrity)
WITH validation AS (

    SELECT
        'gold_dim_product' AS table_name,
        COUNT(*) AS row_count,
        (SELECT COUNT(*) FROM workspace.instacart_silver.products_clean) AS source_row_count,
        SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_key_rows,
        (SELECT COUNT(*) FROM (
            SELECT product_id FROM gold_dim_product
            WHERE product_id IS NOT NULL GROUP BY product_id HAVING COUNT(*) > 1
        )) AS duplicate_keys,
        SUM(CASE WHEN product_name IS NULL THEN 1 ELSE 0 END) AS required_field_issues,
        0 AS unmatched_fk_rows
    FROM gold_dim_product

    UNION ALL

    SELECT
        'gold_dim_order',
        COUNT(*),
        (SELECT COUNT(*) FROM workspace.instacart_silver.orders_clean),
        SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id FROM gold_dim_order
            WHERE order_id IS NOT NULL GROUP BY order_id HAVING COUNT(*) > 1
        )),
        SUM(CASE WHEN user_id IS NULL OR order_number IS NULL THEN 1 ELSE 0 END),
        0
    FROM gold_dim_order

    UNION ALL

    SELECT
        'gold_fact_order_product',
        COUNT(*),
        (SELECT COUNT(*) FROM workspace.instacart_silver.order_products_clean),
        SUM(CASE WHEN order_id IS NULL OR product_id IS NULL THEN 1 ELSE 0 END),
        (SELECT COUNT(*) FROM (
            SELECT order_id, product_id FROM gold_fact_order_product
            WHERE order_id IS NOT NULL AND product_id IS NOT NULL
            GROUP BY order_id, product_id HAVING COUNT(*) > 1
        )),
        0,
        (SELECT COUNT(*) FROM gold_fact_order_product f
            LEFT JOIN gold_dim_order o ON f.order_id = o.order_id
            WHERE f.order_id IS NOT NULL AND o.order_id IS NULL)
         + (SELECT COUNT(*) FROM gold_fact_order_product f
            LEFT JOIN gold_dim_product p ON f.product_id = p.product_id
            WHERE f.product_id IS NOT NULL AND p.product_id IS NULL)
    FROM gold_fact_order_product

)
SELECT
    table_name,
    row_count,
    source_row_count,
    row_count - source_row_count AS row_difference,
    null_key_rows,
    duplicate_keys,
    required_field_issues,
    unmatched_fk_rows,
    CASE
        WHEN null_key_rows > 0 OR duplicate_keys > 0
          OR required_field_issues > 0 OR unmatched_fk_rows > 0
          OR row_count <> source_row_count
        THEN 'REVIEW'
        ELSE 'PASS'
    END AS status
FROM validation
ORDER BY table_name;
```

**Expected**: 3 PASS rows with zero differences and issues

---

**Result Set 2: Measure Reconciliation**

Compares aggregate measures between Silver and Gold:

```sql
-- PART 2: Measure reconciliation (aggregate validation)
WITH silver_measures AS (
    SELECT
        COUNT(*) AS total_order_lines,
        COUNT(DISTINCT order_id) AS distinct_orders,
        COUNT(DISTINCT product_id) AS distinct_products,
        SUM(CASE WHEN reordered = TRUE THEN 1 ELSE 0 END) AS reordered_count,
        SUM(add_to_cart_order) AS total_cart_position_sum
    FROM workspace.instacart_silver.order_products_clean
),
gold_measures AS (
    SELECT
        COUNT(*) AS total_order_lines,
        COUNT(DISTINCT order_id) AS distinct_orders,
        COUNT(DISTINCT product_id) AS distinct_products,
        SUM(CASE WHEN reordered = TRUE THEN 1 ELSE 0 END) AS reordered_count,
        SUM(add_to_cart_order) AS total_cart_position_sum
    FROM gold_fact_order_product
)
SELECT
    'total_order_lines' AS measure,
    s.total_order_lines AS silver_value,
    g.total_order_lines AS gold_value,
    s.total_order_lines - g.total_order_lines AS difference,
    CASE WHEN s.total_order_lines = g.total_order_lines THEN 'PASS' ELSE 'REVIEW' END AS status
FROM silver_measures s, gold_measures g

UNION ALL

SELECT
    'distinct_orders',
    s.distinct_orders,
    g.distinct_orders,
    s.distinct_orders - g.distinct_orders,
    CASE WHEN s.distinct_orders = g.distinct_orders THEN 'PASS' ELSE 'REVIEW' END
FROM silver_measures s, gold_measures g

UNION ALL

SELECT
    'distinct_products',
    s.distinct_products,
    g.distinct_products,
    s.distinct_products - g.distinct_products,
    CASE WHEN s.distinct_products = g.distinct_products THEN 'PASS' ELSE 'REVIEW' END
FROM silver_measures s, gold_measures g

UNION ALL

SELECT
    'reordered_count',
    s.reordered_count,
    g.reordered_count,
    s.reordered_count - g.reordered_count,
    CASE WHEN s.reordered_count = g.reordered_count THEN 'PASS' ELSE 'REVIEW' END
FROM silver_measures s, gold_measures g

UNION ALL

SELECT
    'total_cart_position_sum',
    s.total_cart_position_sum,
    g.total_cart_position_sum,
    s.total_cart_position_sum - g.total_cart_position_sum,
    CASE WHEN s.total_cart_position_sum = g.total_cart_position_sum THEN 'PASS' ELSE 'REVIEW' END
FROM silver_measures s, gold_measures g;
```

**Expected**: 5 PASS rows with all differences = 0

**Note**: The `total_cart_position_sum` is a reconciliation checksum, not purchase quantity. `add_to_cart_order` represents basket position.

### Gold Validation Summary

| Query | Purpose | Expected Output |
|-------|---------|-----------------|
| 18 | Pre-constraint (dimensions) | 2 PASS rows |
| 19 | Constraint checks (PK/FK) | 8 PASS rows with zero violations |
| 20 (Set 1) | Table-level validation | 3 PASS rows with zero differences/issues |
| 20 (Set 2) | Measure reconciliation | 5 PASS rows with zero differences |

**Current Coverage Limits:**
- Reports do not stop execution with `assert_true`
- Check `(order_id, product_id)`, not the agreed `(order_id, add_to_cart_order)` grain key
- Do not explicitly validate basket positions or reordered flag values
- Query 19 reports intended constraints but does NOT register them in Catalog
- Dimension reports do not prove aisle/department completeness or day-name mapping

---

## 4. Analytics Validation

### Purpose
Validate business question outputs and dashboard KPIs.

### Schema
`workspace.instacart_analytics`

### Tables Created

| Task | Output Tables | Business Question |
|------|---------------|-------------------|
| 21 | `analytics_top_departments`, `analytics_top_products` | Q1: Most frequent products/departments |
| 22 | `analytics_day_hour_patterns`, `analytics_basket_size_by_day` | Q2: Purchasing by day/hour |
| 23 | `analytics_reorder_rates` | Q3: Highest reorder behavior |
| 24 | `analytics_product_pairs` | Q4: Products bought together |
| 25 | `analytics_kpis` | All-data dashboard KPIs |

### Consolidated Analytics Validation

**Owner**: Maeve  
**Name**: 25 - Analytics KPIs and Validation  
**Purpose**: Build dashboard KPIs and perform sanity checks across all seven analytics tables  
**Grain**: One KPI summary row and one validation summary row per analytics table

#### Part 1: Build KPIs

```sql
CREATE OR REPLACE TABLE analytics_kpis AS
SELECT
  COUNT(DISTINCT order_id) AS total_orders,
  COUNT(*) AS total_order_lines,
  COUNT(DISTINCT product_id) AS total_products,
  ROUND(
    AVG(CASE WHEN reordered = TRUE THEN 1.0 ELSE 0.0 END),
    4
  ) AS overall_reorder_rate
FROM workspace.instacart_gold.gold_fact_order_product;
```

#### Part 2: Validate All Seven Tables

```sql
WITH validation AS (
  SELECT
    'analytics_top_departments' AS table_name,
    COUNT(*) AS row_count,
    0 AS invalid_values
  FROM analytics_top_departments

  UNION ALL

  SELECT
    'analytics_top_products',
    COUNT(*),
    0
  FROM analytics_top_products

  UNION ALL

  SELECT
    'analytics_day_hour_patterns',
    COUNT(*),
    0
  FROM analytics_day_hour_patterns

  UNION ALL

  SELECT
    'analytics_basket_size_by_day',
    COUNT(*),
    0
  FROM analytics_basket_size_by_day

  UNION ALL

  SELECT
    'analytics_reorder_rates',
    COUNT(*),
    COUNT_IF(
      reorder_rate IS NULL
      OR reorder_rate < 0
      OR reorder_rate > 1
    )
  FROM analytics_reorder_rates

  UNION ALL

  SELECT
    'analytics_product_pairs',
    COUNT(*),
    0
  FROM analytics_product_pairs

  UNION ALL

  SELECT
    'analytics_kpis',
    COUNT(*),
    COUNT_IF(
      overall_reorder_rate IS NULL
      OR overall_reorder_rate < 0
      OR overall_reorder_rate > 1
      OR total_orders <= 0
      OR total_order_lines <= 0
      OR total_products <= 0
      OR total_orders > total_order_lines
      OR total_products > total_order_lines
    )
  FROM analytics_kpis
)
SELECT
  table_name,
  row_count,
  invalid_values,
  CASE
    WHEN row_count > 0
      AND invalid_values = 0
      AND (
        table_name <> 'analytics_kpis'
        OR row_count = 1
      )
    THEN 'PASS'
    ELSE 'REVIEW'
  END AS status
FROM validation
ORDER BY table_name;
```

**Expected**: 7 PASS rows

**What These Checks Validate:**
- All 6 business-question outputs have rows
- `analytics_reorder_rates`: Rate is non-null and between 0 and 1
- `analytics_kpis`: Exactly one row; positive counts; valid overall rate; distinct orders/products ≤ product lines

**What These Checks Do NOT Validate:**
- Individual output keys, measures, or null values
- Complete reconciliation with Gold
- Limits, thresholds, or ranking logic
- Freshness or completeness

---

## 5. Validation Best Practices

### Run Validation After Each Layer

1. **Bronze validation** → before Silver ingestion
2. **Silver validation** → before Gold transformation
3. **Gold validation (3 queries)** → before Analytics build
4. **Analytics validation** → before dashboard refresh

### Status Interpretation

* **PASS**: All checks = 0, safe to proceed
* **REVIEW**: One or more issues detected:
  - Investigate root cause
  - Check if intentional (documented exclusions)
  - Fix upstream if data quality issue
  - Update expected values if business rules changed

### Log Results

Track validation history in a dedicated log table:

```sql
CREATE TABLE IF NOT EXISTS workspace.instacart_gold.validation_log (
  run_timestamp TIMESTAMP,
  layer STRING,
  table_name STRING,
  check_type STRING,
  status STRING,
  issue_count BIGINT,
  notes STRING
);
```

### Alert on Failures

* Email/Slack notification on critical failures
* Stop pipeline on referential integrity violations (REVIEW in Gold FK checks)
* Continue with warnings for minor issues (row_difference in Silver)

### Document Exceptions

* If a validation check returns REVIEW, document WHY
* Add exclusion logic to transformation queries if intentional
* Update expected values in this document if business rules change
* Version control validation queries in project repository


---

**Last Updated**: [Date of pipeline run]  
**Document Owner**: Team (Ina - Silver, Cath - Gold, Maeve - Analytics)  
**Project**: Instacart Data Pipeline  
**Next Review**: After first complete pipeline run
