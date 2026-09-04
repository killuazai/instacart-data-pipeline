# Architecture Documentation

**Instacart Data Engineering Pipeline — Technical Architecture**

---

## 1. System Overview

The Instacart data pipeline follows the **Medallion Architecture** pattern (Bronze → Silver → Gold) to transform raw CSV data into a production-ready dimensional star schema.

```
SOURCE (CSV Files)
    ↓
BRONZE (Raw Ingestion) — workspace.instacart_bronze
    ↓
SILVER (Cleaned & Standardized) — workspace.instacart_silver
    ↓
GOLD (Dimensional Star Schema) — workspace.instacart_gold
    ↓
ANALYTICS (Pre-Aggregated Business Answers) — workspace.instacart_analytics
    ↓
BUSINESS ANALYTICS DASHBOARD
```

### Architecture Principles

1. **Separation of Concerns**: Each layer has a distinct purpose
2. **Immutability**: Bronze preserves raw data; transformations are additive
3. **Progressive Quality**: Data quality improves through each layer
4. **Referential Integrity**: Unity Catalog constraints enforce FK relationships
5. **Auditability**: Metadata columns (`loaded_at`) track data lineage

---

## 2. Source Layer

Source data consists of six CSV files from Cloudflare R2 storage representing Instacart's market basket analysis dataset.

### Source Datasets

#### 2.1 `aisles.csv`
* **Purpose**: Product aisle classifications
* **Row Count**: 134
* **Schema**: `aisle_id` (INT), `aisle` (STRING)
* **Grain**: One row per aisle

#### 2.2 `departments.csv`
* **Purpose**: Product department classifications
* **Row Count**: 21
* **Schema**: `department_id` (INT), `department` (STRING)
* **Grain**: One row per department

#### 2.3 `products.csv`
* **Purpose**: Product catalog
* **Row Count**: 49,688
* **Schema**: `product_id` (INT), `product_name` (STRING), `aisle_id` (STRING), `department_id` (STRING)
* **Grain**: One row per product
* **Data Quality Issue**: `aisle_id` and `department_id` incorrectly typed as STRING

#### 2.4 `orders.csv`
* **Purpose**: Order header with temporal attributes
* **Row Count**: 3,421,083
* **Schema**: 
  * `order_id` (INT)
  * `user_id` (INT)
  * `eval_set` (STRING)
  * `order_number` (INT)
  * `order_dow` (INT) — Day of week (0=Sunday)
  * `order_hour_of_day` (INT)
  * `days_since_prior_order` (DOUBLE) — NULL for first orders
* **Grain**: One row per order

#### 2.5 `order_products__prior.csv`
* **Purpose**: Historical order line items
* **Row Count**: 32,434,489
* **Schema**: `order_id` (INT), `product_id` (INT), `add_to_cart_order` (INT), `reordered` (INT)
* **Grain**: One row per product per order

#### 2.6 `order_products__train.csv`
* **Purpose**: Training set order line items
* **Row Count**: 1,384,617
* **Schema**: `order_id` (INT), `product_id` (INT), `add_to_cart_order` (INT), `reordered` (INT)
* **Grain**: One row per product per order

---

## 3. Bronze Layer

**Purpose**: Ingest raw CSV data with minimal transformation. Preserve source integrity.

**Catalog/Schema**: `workspace.instacart_bronze`

**Ingestion Method**: Databricks `read_files()` with Auto Loader

### Bronze Tables

All Bronze tables include `_rescued_data` column for malformed records (validated as all NULL).

#### 3.1 `bronze_aisles`
* **Source**: `aisles.csv`
* **Row Count**: 134
* **Schema**: `aisle_id` (INT), `aisle` (STRING), `_rescued_data` (STRING)

#### 3.2 `bronze_departments`
* **Source**: `departments.csv`
* **Row Count**: 21
* **Schema**: `department_id` (INT), `department` (STRING), `_rescued_data` (STRING)

#### 3.3 `bronze_products`
* **Source**: `products.csv`
* **Row Count**: 49,688
* **Schema**: `product_id` (INT), `product_name` (STRING), `aisle_id` (STRING), `department_id` (STRING), `_rescued_data` (STRING)
* **Known Issue**: `aisle_id` and `department_id` remain STRING (fixed in Silver)

#### 3.4 `bronze_orders`
* **Source**: `orders.csv`
* **Row Count**: 3,421,083
* **Schema**: `order_id` (INT), `user_id` (INT), `eval_set` (STRING), `order_number` (INT), `order_dow` (INT), `order_hour_of_day` (INT), `days_since_prior_order` (DOUBLE), `_rescued_data` (STRING)

#### 3.5 `bronze_order_products_prior`
* **Source**: `order_products__prior.csv`
* **Row Count**: 32,434,489
* **Schema**: `order_id` (INT), `product_id` (INT), `add_to_cart_order` (INT), `reordered` (INT), `_rescued_data` (STRING)

#### 3.6 `bronze_order_products_train`
* **Source**: `order_products__train.csv`
* **Row Count**: 1,384,617
* **Schema**: `order_id` (INT), `product_id` (INT), `add_to_cart_order` (INT), `reordered` (INT), `_rescued_data` (STRING)

### Bronze Validation

**Validation Method**: One consolidated query (Query 08) checks all 6 Bronze tables using `UNION ALL` to produce a single result set with table-level pass/fail results.

**Validation Checks** (applied to each table):

| Check | What it verifies | Status impact |
|-------|------------------|---------------|
| **Expected vs Actual Rows** | Actual row count must match hardcoded expected count | FAIL if difference ≠ 0 |
| **Null Required IDs** | Required identifiers (IDs, key fields) must not be NULL | FAIL if > 0 |
| **Duplicate Primary Keys** | Single-column and composite keys must be unique | FAIL if > 0 |
| **Duplicate Alternate Keys** | Alternate candidate keys (e.g., user_id + order_number) must be unique | FAIL if > 0 |
| **Required Field Issues** | Descriptive names and required context fields must not be blank/NULL | FAIL if > 0 |
| **Domain Issues** | Valid eval_set labels; day codes 0-6; hours 0-23; positive order numbers and basket positions; reordered is 0 or 1; valid prior-order intervals | FAIL if > 0 |
| **Rescued Rows** | No non-null `_rescued_data` remains | FAIL if > 0 |

**Status Logic**: A table is `PASS` only when:
* `row_difference = 0` (actual matches expected)
* `null_required_ids = 0`
* `duplicate_primary_keys = 0`
* `duplicate_alternate_keys = 0`
* `required_field_issues = 0`
* `domain_issues = 0`
* `rescued_rows = 0`

Otherwise: `status = 'FAIL'`

**Important Differences from Silver/Gold**:
* Bronze uses `FAIL` status (not `REVIEW`)
* Bronze validation includes `assert_true` to STOP the pipeline on failure
* `row_difference = 0` is REQUIRED (Bronze does not intentionally drop rows)
* Expected row counts are hardcoded (not dynamically read from source)

**Expected Hardcoded Row Counts**:
* aisles: 134
* departments: 21
* products: 49,688
* orders: 3,421,083
* order_products_prior: 32,434,489
* order_products_train: 1,384,617

**Expected Result**: 6 PASS rows; `bronze_validation_check` may be NULL (normal when assertion succeeds)

**When a Check Fails**: The `assert_true` can prevent the complete result table from displaying. For diagnostics, inspect the same metrics with the assertion omitted in a separate copy, then keep the assertion in the pipeline version.

**Counting Note**: For single-column keys, the current `COUNT(*) - COUNT(DISTINCT key)` expression also counts null-key rows. Read it alongside `null_required_ids`; it is not a count of distinct duplicate-key groups.

**Design Note**: Cross-table relationship checks (FKs) are left to Silver rather than repeated as joins in Bronze validation.

**Prior-Order Interval Rules** (validated in Bronze):
* Must be non-negative when present
* Must be NULL for first orders (`order_number = 1`)
* Must be present for later orders (`order_number > 1`)

---

## 4. Silver Layer

**Purpose**: Clean, standardize, and validate Bronze data. Fix data types, filter invalid records.

**Catalog/Schema**: `workspace.instacart_silver`

### Silver Tables

#### 4.1 `silver_aisles`
* **Source**: `bronze_aisles`
* **Row Count**: 134 (0 dropped)
* **Schema**: `aisle_id` (INT), `aisle` (STRING), `loaded_at` (TIMESTAMP)
* **Transformations**:
  * Drop `_rescued_data`
  * Filter NULL values
  * Add `loaded_at` metadata

#### 4.2 `silver_departments`
* **Source**: `bronze_departments`
* **Row Count**: 21 (0 dropped)
* **Schema**: `department_id` (INT), `department` (STRING), `loaded_at` (TIMESTAMP)
* **Transformations**: Same as silver_aisles

#### 4.3 `silver_products`
* **Source**: `bronze_products`
* **Row Count**: 49,687 (1 dropped)
* **Schema**: `product_id` (INT), `product_name` (STRING), `aisle_id` (INT), `department_id` (INT), `loaded_at` (TIMESTAMP)
* **Transformations**:
  * **CAST** `aisle_id` from STRING → INT
  * **CAST** `department_id` from STRING → INT
  * Drop `_rescued_data`
  * Filter NULLs
  * Add `loaded_at`

#### 4.4 `silver_orders`
* **Source**: `bronze_orders`
* **Row Count**: 3,346,083 (75,000 dropped)
* **Schema**: `order_id` (INT), `user_id` (INT), `eval_set` (STRING), `order_number` (INT), `order_dow` (INT), `order_hour_of_day` (INT), `days_since_prior_order` (DOUBLE), `loaded_at` (TIMESTAMP)
* **Transformations**:
  * Filter NULL `order_id` and `user_id`
  * Preserve NULL `days_since_prior_order` (valid for first orders)
  * Add `loaded_at`
* **Data Quality**: 75,000 orders dropped (NULL user_id or order_id)

#### 4.5 `silver_order_products`
* **Source**: `bronze_order_products_prior` UNION `bronze_order_products_train`
* **Row Count**: 33,819,106 (0 dropped)
* **Schema**: `order_id` (INT), `product_id` (INT), `add_to_cart_order` (INT), `reordered` (INT), `source_system` (STRING), `loaded_at` (TIMESTAMP)
* **Transformations**:
  * **UNION** prior + train datasets
  * Add `source_system` column ('prior' or 'train')
  * Filter NULLs
  * Add `loaded_at`

### Silver Validation

**Validation Method**: One consolidated query (Query 14) checks all 5 Silver tables using `UNION ALL` to produce a single result set with table-level pass/review results.

**Validation Checks** (applied to each table):

| Check | What it verifies | Status impact |
|-------|------------------|---------------|
| **Row Reconciliation** | Compare Silver row count vs Bronze source(s) | Informational only - does NOT fail validation |
| **Null Key Rows** | Required identifiers (IDs, FK fields) must not be NULL | REVIEW if > 0 |
| **Duplicate Keys** | Primary keys and candidate keys must be unique | REVIEW if > 0 |
| **Required Field Issues** | Names and descriptive fields must not be blank/NULL; products must not contain backslash artifacts | REVIEW if > 0 |
| **Unmatched FK Rows** | Foreign keys must resolve to existing records in referenced Silver tables | REVIEW if > 0 |

**Status Logic**: A table is `PASS` only when:
* `null_key_rows = 0`
* `duplicate_keys = 0`
* `required_field_issues = 0`
* `unmatched_fk_rows = 0`

Otherwise: `status = 'REVIEW'`

**Important**: `row_difference` is shown but does NOT affect status. Silver intentionally drops rows (orphan FKs, out-of-range values), so non-zero differences are expected. See Decision 17 in decisions.md.

**Validation Results**:

1. **Row Reconciliation** (informational):
   * aisles: 134 → 134 (0 dropped) ✓
   * departments: 21 → 21 (0 dropped) ✓
   * products: 49,688 → 49,687 (1 dropped) ✓
   * orders: 3,421,083 → 3,346,083 (75,000 dropped) ✓
   * order_products: 33,819,106 → 33,819,106 (0 dropped) ✓

2. **Data Quality Checks**:
   * Type Conversions: `aisle_id` and `department_id` successfully cast to INT ✓
   * Primary Key Uniqueness: Zero duplicates in all ID columns ✓
   * Required Fields: No blank/null names, no backslash artifacts in products ✓

3. **Referential Integrity**:
   * products → aisles: 0 orphans ✓
   * products → departments: 0 orphans ✓
   * order_products → orders: 0 orphans ✓
   * order_products → products: **3 orphans** ⚠ (dropped before Gold)

**Expected Result**: `status = 'PASS'` on all 5 rows

**Design Note**: Unlike Bronze validation (which uses `FAIL` status and `assert_true` to stop the pipeline), Silver validation uses `PASS`/`REVIEW` and is informational. The consolidated query pattern makes it easy to add a 6th table later - just copy one `UNION ALL` block.

---

## 5. Gold Layer

**Purpose**: Build dimensional star schema with Unity Catalog constraints. Optimize for analytics.

**Catalog/Schema**: `workspace.instacart_gold`

**Modeling Approach**: Kimball Star Schema

### Gold Tables

#### 5.1 `dim_product` — Product Dimension

* **Source**: `silver_products` + `silver_aisles` + `silver_departments` (denormalized joins)
* **Row Count**: 49,687
* **Grain**: One row per product
* **Primary Key**: `product_id` (Unity Catalog constraint)
* **Schema**:
  * `product_id` (INT, NOT NULL) — PK
  * `product_name` (STRING)
  * `aisle_id` (INT)
  * `aisle_name` (STRING)
  * `department_id` (INT)
  * `department_name` (STRING)
  * `product_hierarchy` (STRING) — Concatenated: "department / aisle / product"
  * `loaded_at` (TIMESTAMP)

**Purpose**: Product dimension with denormalized hierarchy for filtering and drill-down.

#### 5.2 `dim_order` — Order Dimension

* **Source**: `silver_orders` with derived temporal attributes
* **Row Count**: 3,346,083
* **Grain**: One row per order
* **Primary Key**: `order_id` (Unity Catalog constraint)
* **Schema**:
  * `order_id` (INT, NOT NULL) — PK
  * `user_id` (INT) — Customer identifier
  * `eval_set` (STRING) — 'prior' or 'train'
  * `order_number` (INT) — Customer's order sequence
  * `order_dow` (INT) — Day of week (0-6)
  * `day_of_week_name` (STRING) — 'Sunday', 'Monday', etc.
  * `order_hour_of_day` (INT) — Hour (0-23)
  * `time_of_day_bucket` (STRING) — 'Early Morning', 'Morning', 'Afternoon', 'Evening', 'Night'
  * `days_since_prior_order` (DOUBLE) — NULL for first order
  * `loaded_at` (TIMESTAMP)

**Purpose**: Order dimension with temporal attributes for time-based analysis.

**Time Buckets**:
* 0-5: Early Morning
* 6-11: Morning
* 12-17: Afternoon
* 18-21: Evening
* 22-23: Night

#### 5.3 `fact_order_product` — Fact Table

* **Source**: `silver_order_products` + `silver_orders` (for user_id)
* **Row Count**: 33,819,103 (3 orphan products dropped)
* **Grain**: **One row per product per order** (order line item)
* **Primary Key**: Composite (`order_id`, `add_to_cart_order`) — Unity Catalog constraint
* **Foreign Keys**: 
  * `product_id` → `dim_product.product_id`
  * `order_id` → `dim_order.order_id`
* **Schema**:
  * `order_id` (INT, NOT NULL) — PK component, FK to dim_order
  * `product_id` (INT, NOT NULL) — FK to dim_product
  * `add_to_cart_order` (INT, NOT NULL) — PK component, sequence in cart
  * `reordered` (BOOLEAN) — Measure: repeat purchase indicator
  * `user_id` (INT) — Denormalized from orders for convenience
  * `source_system` (STRING) — 'prior' or 'train'
  * `loaded_at` (TIMESTAMP)

**Measures**:
1. `add_to_cart_order`: Position in shopping cart (semi-additive)
2. `reordered`: Binary indicator (fully additive, SUM = reorder count, AVG = reorder rate)

**Unity Catalog Constraints**:
* Primary Key: `fact_order_product_pk` on (`order_id`, `add_to_cart_order`)
* Foreign Key: `fact_order_product_product_fk` on `product_id`
* Foreign Key: `fact_order_product_order_fk` on `order_id`

### Star Schema Diagram

```
        dim_product
        (49,687 products)
              |
              | product_id (PK)
              |
              | (FK)
              ↓
    fact_order_product ←─────── dim_order
    (33.8M line items)          (3.3M orders)
         PK: (order_id,
              add_to_cart_order)
              ↑
              | (FK)
              |
              | order_id (PK)
```

### Gold Validation

**Validation Method**: Three-stage validation process (Queries 18-20) with increasing scope:

#### Query 18: Pre-Constraint Validation (Dimensions Only)

**Purpose**: Validate dimension tables before building the fact table (though notebook places this after Query 17)

**Checks** (one row per dimension):

| Check | What it verifies | Status impact |
|-------|------------------|---------------|
| **Row Count** | Total rows per dimension | Informational |
| **Null Key Rows** | Primary key candidates must not be NULL | REVIEW if > 0 |
| **Duplicate Keys** | Primary keys must be unique | REVIEW if > 0 |
| **Required Field Issues** | Product names (dim_product), user_id/order_number (dim_order) must not be NULL | REVIEW if > 0 |

**Status Logic**: `PASS` only when `null_key_rows = 0 AND duplicate_keys = 0 AND required_field_issues = 0`

**Expected Result**: 2 PASS rows (gold_dim_product, gold_dim_order)

---

#### Query 19: Constraint Checks (All Tables)

**Purpose**: Validate PK/FK constraints across all Gold tables

**Note**: Despite the name, this query only **checks** the data - it does NOT execute `ALTER TABLE ... ADD CONSTRAINT` or register keys in Unity Catalog

**Checks** (8 constraint validation rows):

1. **PK: gold_dim_product.product_id** - Primary Key Uniqueness
2. **PK: gold_dim_order.order_id** - Primary Key Uniqueness
3. **PK: gold_fact_order_product (order_id, product_id)** - Composite Key Uniqueness
4. **PK: gold_dim_product.product_id NOT NULL** - Primary Key Null Check
5. **PK: gold_dim_order.order_id NOT NULL** - Primary Key Null Check
6. **PK: gold_fact_order_product (order_id, product_id) NOT NULL** - Composite Key Null Check
7. **FK: gold_fact_order_product.order_id → gold_dim_order.order_id** - Foreign Key Integrity
8. **FK: gold_fact_order_product.product_id → gold_dim_product.product_id** - Foreign Key Integrity

**Status Logic**: `PASS` when `violations = 0`, otherwise `REVIEW`

**Expected Result**: 8 PASS rows with zero violations

**Coverage Note**: This query validates the composite key `(order_id, product_id)`, not the agreed grain key `(order_id, add_to_cart_order)`. See decisions.md for grain discussion.

---

#### Query 20: Final Validation (Comprehensive)

**Purpose**: Complete Gold validation with two result sets

**Result Set 1 - Table-Level Checks** (3 rows, one per table):

| Check | What it verifies | Status impact |
|-------|------------------|---------------|
| **Row Count** | Gold table row count | Informational |
| **Source Row Count** | Silver source row count | Informational |
| **Row Difference** | `row_count - source_row_count` | REVIEW if ≠ 0 (Gold should preserve Silver rows) |
| **Null Key Rows** | Required identifiers must not be NULL | REVIEW if > 0 |
| **Duplicate Keys** | Primary/composite keys must be unique | REVIEW if > 0 |
| **Required Field Issues** | Names and descriptive fields must not be NULL | REVIEW if > 0 |
| **Unmatched FK Rows** | Fact FKs must resolve to dimension records | REVIEW if > 0 |

**Status Logic**: `PASS` only when ALL checks pass (zero issues AND `row_count = source_row_count`)

**Important**: Unlike Silver, Gold `row_difference ≠ 0` causes `REVIEW` because Gold builds are intended to preserve Silver rows exactly.

**Expected Result**: 3 PASS rows (gold_dim_product, gold_dim_order, gold_fact_order_product)

---

**Result Set 2 - Measure Reconciliation** (5 rows, one per measure):

**Purpose**: Verify aggregate measures match between Silver and Gold

| Measure | What it checks |
|---------|----------------|
| `total_order_lines` | Total product-line purchase events |
| `distinct_orders` | Orders represented in the fact |
| `distinct_products` | Products represented in the fact |
| `reordered_count` | Rows where `reordered = TRUE` |
| `total_cart_position_sum` | Checksum of stored basket positions (reconciliation only, not quantity) |

**Calculation**: `difference = silver_value - gold_value`

**Status Logic**: `PASS` when `difference = 0`, otherwise `REVIEW`

**Expected Result**: 5 PASS rows with zero differences

**Note**: The cart-position sum is a reconciliation checksum only. Matching aggregate totals do not prove every individual row matches.

---

**Validation Results Summary**:

1. **Query 18**: 2 PASS rows (dimensions)
2. **Query 19**: 8 PASS rows (constraints)
3. **Query 20 Set 1**: 3 PASS rows (table-level)
4. **Query 20 Set 2**: 5 PASS rows (measures)

**Design Note**: Unlike Bronze validation (uses `FAIL` and `assert_true` to stop the pipeline), Gold validation uses `PASS`/`REVIEW` and is informational. No validation query halts execution on failure.

---

## 6. Analytics Layer

**Purpose**: Pre-aggregate business question answers into small, dashboard-ready tables. Avoid re-scanning the 33.8M-row fact table on every dashboard load.

**Catalog/Schema**: `workspace.instacart_analytics`

**Design Principle**: Each business question gets its own materialized table. Dashboard queries read from these analytics tables, not from `gold_fact_order_product` directly.

### Analytics Tables

#### 6.1 `analytics_top_departments`

* **Business Question**: Which departments are purchased most frequently?
* **Source**: `gold_fact_order_product` + `gold_dim_product`
* **Row Count**: 21 (one per department)
* **Grain**: One row per department
* **Schema**:
  * `department_name` (STRING)
  * `order_line_count` (BIGINT) — Total product lines purchased
  * `distinct_orders` (BIGINT) — Number of orders containing this department
* **Sort**: Descending by `order_line_count`

#### 6.2 `analytics_top_products`

* **Business Question**: Which products are purchased most frequently?
* **Source**: `gold_fact_order_product` + `gold_dim_product`
* **Row Count**: 50 (top 50 only)
* **Grain**: One row per product
* **Schema**:
  * `product_name` (STRING)
  * `department_name` (STRING)
  * `aisle_name` (STRING)
  * `order_line_count` (BIGINT) — Total times purchased
* **Sort**: Descending by `order_line_count`
* **Filter**: `LIMIT 50`

#### 6.3 `analytics_day_hour_patterns`

* **Business Question**: How does customer purchasing behavior change by day of week and hour of day?
* **Source**: `gold_fact_order_product` + `gold_dim_order`
* **Row Count**: ~168 (7 days × 24 hours, sparse)
* **Grain**: One row per (day of week, hour of day)
* **Schema**:
  * `order_day_name` (STRING) — 'Sunday', 'Monday', etc.
  * `order_hour_of_day` (INT) — 0-23
  * `order_line_count` (BIGINT) — Total product lines purchased
  * `distinct_orders` (BIGINT) — Number of orders
* **Sort**: Descending by `order_line_count`
* **Dashboard Usage**: Render as heatmap (day × hour, color = volume)

#### 6.4 `analytics_basket_size_by_day`

* **Business Question**: Companion metric for Q2 — average basket size by day
* **Source**: `gold_fact_order_product` + `gold_dim_order`
* **Row Count**: 7 (one per day of week)
* **Grain**: One row per day of week
* **Schema**:
  * `order_day_name` (STRING)
  * `avg_items_per_order` (DOUBLE) — Average products per order
* **Sort**: Descending by `avg_items_per_order`
* **Purpose**: Inventory/staffing insight (busiest days + largest baskets)

#### 6.5 `analytics_reorder_rates`

* **Business Question**: Which products have the highest reorder behavior?
* **Source**: `gold_fact_order_product` + `gold_dim_product`
* **Row Count**: 50 (top 50 only)
* **Grain**: One row per product
* **Schema**:
  * `product_name` (STRING)
  * `department_name` (STRING)
  * `total_order_lines` (BIGINT) — Total times purchased
  * `reorder_count` (BIGINT) — Times purchased as reorder
  * `reorder_rate` (DOUBLE) — `reorder_count / total_order_lines`, rounded to 4 decimals
* **Filter**: `HAVING COUNT(*) >= 500` (minimum volume threshold)
* **Sort**: Descending by `reorder_rate`
* **Rationale**: Prevents products with n=1 (100% or 0% rate) from outranking genuinely popular items

#### 6.6 `analytics_product_pairs`

* **Business Question** (Team's question): Which products are most often bought together?
* **Source**: `gold_fact_order_product` (self-join) + `gold_dim_product`
* **Row Count**: 50 (top 50 pairs only)
* **Grain**: One row per unordered product pair (product_a, product_b)
* **Schema**:
  * `product_a` (STRING) — First product name
  * `product_b` (STRING) — Second product name
  * `times_bought_together` (BIGINT) — Co-purchase count
* **Optimization**: Self-join restricted to top 200 products by volume before pairing
* **Filter**: `f1.product_id < f2.product_id` (keeps each pair once, not twice)
* **Sort**: Descending by `times_bought_together`
* **Dashboard Usage**: Cross-sell / market basket recommendations

#### 6.7 `analytics_kpis`

* **Purpose**: Precompute headline metrics for dashboard KPI cards
* **Source**: `gold_fact_order_product`
* **Row Count**: 1 (single summary row)
* **Grain**: Aggregated totals
* **Schema**:
  * `total_orders` (BIGINT) — Distinct order count
  * `total_order_lines` (BIGINT) — Total product lines
  * `total_products` (BIGINT) — Distinct product count
  * `overall_reorder_rate` (DOUBLE) — Global reorder rate, rounded to 4 decimals
* **Purpose**: Avoid rescanning fact table for simple dashboard summary cards

### Analytics Validation

**Validation Method**: Task 25 builds `analytics_kpis` first, then runs one consolidated sanity check across all 7 analytics tables.

**Validation Approach**: Lightweight sanity checks (not complete reconciliation with Gold)

#### Task 25: Analytics KPIs and Validation

**Part 1: Build KPIs Table**

`analytics_kpis` is built directly from `gold_fact_order_product` and contains one summary row:

| KPI | Meaning |
|-----|----------|
| `total_orders` | Distinct orders represented in the fact |
| `total_order_lines` | Product-line purchase count |
| `total_products` | Distinct products actually purchased (not total product-dimension rows) |
| `overall_reorder_rate` | Share of product lines marked reordered, rounded to 4 decimals |

**Important**: These are all-data KPIs computed from the full Gold fact, NOT derived by summing distinct counts or averaging rates from top-product/department tables.

---

**Part 2: Validation Checks** (7 rows, one per analytics table):

| Table | Checks Performed | Status Logic |
|-------|------------------|-------------|
| `analytics_top_departments` | Has rows | `PASS` if `row_count > 0` |
| `analytics_top_products` | Has rows | `PASS` if `row_count > 0` |
| `analytics_day_hour_patterns` | Has rows | `PASS` if `row_count > 0` |
| `analytics_basket_size_by_day` | Has rows | `PASS` if `row_count > 0` |
| `analytics_reorder_rates` | Has rows; `reorder_rate` is non-null and between 0 and 1 | `PASS` if `row_count > 0 AND invalid_values = 0` |
| `analytics_product_pairs` | Has rows | `PASS` if `row_count > 0` |
| `analytics_kpis` | Exactly 1 row; positive counts; valid overall rate; distinct orders/products ≤ product lines | `PASS` if `row_count = 1 AND invalid_values = 0` |

**Status Logic**: A table is `PASS` when:
* `row_count > 0`
* `invalid_values = 0`
* For `analytics_kpis` only: `row_count = 1` (single summary row)

Otherwise: `status = 'REVIEW'`

**Expected Result**: 7 PASS rows

**Note on `invalid_values`**: This field is `0` (constant) for the five outputs that receive only a non-empty-table check. It does NOT mean their measures, keys, or null values were independently validated.

---

**Build Order & Dependencies** (from notebooks):

| Task | Output Tables | Depends On |
|------|---------------|------------|
| **21** | `analytics_top_departments`, `analytics_top_products` | Gold fact + product dimension |
| **22** | `analytics_day_hour_patterns`, `analytics_basket_size_by_day` | Gold fact + order dimension; daily output reuses day/hour output |
| **23** | `analytics_reorder_rates` | Gold fact + product dimension |
| **24** | `analytics_product_pairs` | Gold fact + product dimension |
| **25** | `analytics_kpis` + validation report | Gold fact + all six outputs from Tasks 21-24 |

**Job DAG**: Tasks 21-24 are independent and can run in parallel. Task 25 must wait for all four.

### Query Performance Rationale

**Why Pre-Aggregate?**

* **Without Analytics Layer**: Every dashboard load scans 33.8M-row fact table
* **With Analytics Layer**: Dashboard reads small tables (7-168 rows each)
* **Performance Gain**: ~100x faster dashboard loads
* **Trade-off**: Analytics tables must be refreshed when Gold updates (acceptable for batch pipeline)

**Market Basket Analysis (Product Pairs) Optimization**:

* **Naive approach**: Self-join all 33.8M fact rows → finds mostly noise (rare pairings)
* **Optimized approach**: Restrict to top 200 products → reduces join size by ~2 orders of magnitude
* **Rationale**: Rare pairings aren't actionable for cross-sell; top-200 filter catches all meaningful pairs while keeping query tractable

---

## 7. Dashboard

**Dashboard Name**: Instacart Customer & Purchase Analytics

**Dashboard Type**: Lakeview Dashboard (AI/BI)

**Data Sources**: 
* **Primary**: `workspace.instacart_analytics.*` (pre-aggregated business question answers)
* **Backup**: `workspace.instacart_gold.*` (for ad-hoc/custom queries not covered by analytics tables)

**Dashboard Components**:

1. **KPI Cards** (Source: `analytics_kpis`):
   * Total Orders: `total_orders`
   * Total Product Lines: `total_order_lines`
   * Unique Products: `total_products`
   * Overall Reorder Rate: `overall_reorder_rate`

2. **Product Analysis**:
   * **Top Departments** (Source: `analytics_top_departments`) — Bar chart, all 21 departments
   * **Top Products** (Source: `analytics_top_products`) — Table, top 50 by volume
   * **Highest Reorder Rates** (Source: `analytics_reorder_rates`) — Bar chart, top 50 loyalty products

3. **Temporal Analysis**:
   * **Purchase Heatmap** (Source: `analytics_day_hour_patterns`) — Day × Hour heatmap
   * **Basket Size by Day** (Source: `analytics_basket_size_by_day`) — Bar chart, avg items/order

4. **Market Basket Analysis**:
   * **Products Bought Together** (Source: `analytics_product_pairs`) — Table, top 50 pairs
   * **Purpose**: Cross-sell recommendations

**Performance**: 
* Analytics tables: < 0.5 seconds per query (reading pre-aggregated tables with 7-168 rows)
* Direct Gold queries: 1-3 seconds (only for ad-hoc exploration not covered by analytics layer)

**Design Philosophy**: 
* Dashboard reads from `analytics_*` tables (small, fast)
* Never queries `gold_fact_order_product` directly (33.8M rows — too slow for dashboard loads)
* Analytics tables refreshed during pipeline runs (acceptable staleness for batch reporting)

---

## 8. Data Lineage Summary

```
Source CSV                  → Bronze                        → Silver                    → Gold                    → Analytics
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
aisles.csv                  → bronze_aisles                 → silver_aisles             → dim_product.aisle_*     → analytics_top_*
departments.csv             → bronze_departments            → silver_departments        → dim_product.dept_*      → analytics_top_departments
products.csv                → bronze_products               → silver_products           → dim_product             → analytics_top_products
                                                                                                                   analytics_reorder_rates
                                                                                                                   analytics_product_pairs
orders.csv                  → bronze_orders                 → silver_orders             → dim_order               → analytics_day_hour_patterns
                                                                                                                   analytics_basket_size_by_day
order_products__prior.csv   → bronze_order_products_prior   → silver_order_products     → fact_order_product      → analytics_kpis
order_products__train.csv   → bronze_order_products_train  →   (union with prior)      →   (joins to dims)       →   (aggregates to answers)
```

**Key Transformations**:
* **Bronze → Silver**: Type fixes (STRING → INT), NULL filtering, UNION datasets, backslash removal
* **Silver → Gold**: Denormalization, derived attributes (day names, time buckets), Unity Catalog constraints
* **Gold → Analytics**: Pre-aggregation by business question (departments, products, day/hour, reorder rates, product pairs, KPIs)

**Validation Philosophy Across Layers**:

| Layer | Status Values | Stops Pipeline? | Row Difference Policy | Purpose |
|-------|---------------|----------------|----------------------|----------|
| **Bronze** | `PASS` / `FAIL` | ✓ Yes (`assert_true`) | Must be 0 (no intentional drops) | Gate: prevent bad data from entering pipeline |
| **Silver** | `PASS` / `REVIEW` | ✗ No (informational) | Informational only (intentional drops expected) | Report: document cleaning results |
| **Gold** | `PASS` / `REVIEW` | ✗ No (informational) | Must be 0 (should preserve Silver rows) | Report: verify dimensional integrity |
| **Analytics** | `PASS` / `REVIEW` | ✗ No (informational) | N/A (aggregated outputs, not 1:1) | Sanity check: confirm tables exist and are reasonable |

**Key Insight**: Only Bronze validation is a hard gate. Silver/Gold/Analytics validations are informational checkpoints that document data quality without halting execution.

---

## 9. Performance Metrics (will change after i make the pipeline)

| Layer | Execution Time | Records Processed | Output |
|-------|----------------|-------------------|--------|
| **Bronze** | ~2 minutes | 37.3M rows | 6 tables |
| **Silver** | ~3 minutes | 37.2M rows (75K filtered) | 5 tables |
| **Gold** | ~5 minutes | 33.8M fact rows + 3.4M dimension rows | 3 tables (2 dims + 1 fact) |
| **Analytics** | ~2 minutes | 33.8M fact rows aggregated | 7 tables (small, pre-aggregated) |
| **End-to-End** | ~12 minutes | Full pipeline | 21 tables total |

**Compute**: Databricks Serverless SQL Warehouse

**Storage**: Delta Lake format, Unity Catalog managed

**Dashboard Query Performance**:
* Analytics tables: < 0.5 seconds (reading 7-168 rows)
* Gold fact table: 1-3 seconds (scanning 33.8M rows) — used only for ad-hoc queries

---

## 10. Technical Stack

* **Platform**: Databricks
* **Catalog**: Unity Catalog
* **Storage**: Delta Lake (S3-backed)
* **Compute**: Serverless SQL Warehouse
* **Languages**: SQL (primary), Python (validation notebooks)
* **Architecture**: Medallion (Bronze → Silver → Gold)
* **Modeling**: Kimball Dimensional Modeling
* **Constraints**: Unity Catalog Primary Keys & Foreign Keys
* **Version Control**: Git / GitHub

---

## 11. Known Issues & Limitations

### Data Quality Issues

**75,000 Orders Dropped**
* **Description**: Orders with NULL `user_id` or `order_id`
* **Impact**: ~2.2% of orders excluded from Silver layer
* **Status**: Expected behavior; data quality filter

### Design Decisions

**No Separate Customer Dimension**
* **Decision**: Customer attributes embedded in `dim_order`
* **Reason**: Simplified star schema for initial implementation
* **Future**: May split into `dim_customer` in Phase 2

**Analytics Layer in Separate Schema**
* **Current State**: Pre-aggregated business question answers in `workspace.instacart_analytics`
* **Rationale**: Dashboard reads small analytics tables (7-168 rows) instead of scanning 33.8M-row fact table
* **Performance Impact**: ~100x faster dashboard loads vs. querying Gold directly

---

## 12. Team Contributions

**Layer Ownership:**
* **Nadine**: Bronze layer design, ingestion strategy, CSV parsing configuration
* **Ina**: Silver layer engineering, data quality rules, Silver-to-Silver dependencies
* **Cath**: Gold layer star schema, Unity Catalog constraints, multi-stage validation
* **Maeve**: Analytics layer business questions, pre-aggregation strategy, dashboard optimization

**Supporting Work:**
* **Documentation**: Architecture, data model, data dictionary, decisions log
* **Validation**: End-to-end quality checks across all layers
* **Dashboard**: Lakeview dashboard consuming Analytics tables

---


---

**Last Updated**: 2026-09-04  
**Architecture Version**: 2.1 (Complete validation documentation with build orders and dependencies)  
**Maintained By**: FTW Data Engineering Batch 12
