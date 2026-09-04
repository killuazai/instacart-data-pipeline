# Architecture Documentation

**Instacart Data Engineering Pipeline — Technical Architecture**

---

## 1. System Overview

The Instacart data pipeline follows the **Medallion Architecture** pattern (Bronze → Silver → Gold) to transform raw CSV data into a production-ready dimensional star schema.

```
SOURCE (CSV Files)
    ↓
BRONZE (Raw Ingestion) — workspace.default
    ↓
SILVER (Cleaned & Standardized) — workspace.default
    ↓
GOLD (Dimensional Star Schema) — workspace.instacart_gold
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

**Catalog/Schema**: `workspace.default`

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

* ✓ All source files successfully ingested
* ✓ Zero malformed records (`_rescued_data` all NULL)
* ✓ Row counts match source
* ✓ All primary keys present (no NULLs in ID columns)

---

## 4. Silver Layer

**Purpose**: Clean, standardize, and validate Bronze data. Fix data types, filter invalid records.

**Catalog/Schema**: `workspace.default`

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

**Data Quality Checks**:

1. **Row Reconciliation**:
   * aisles: 134 → 134 ✓
   * departments: 21 → 21 ✓
   * products: 49,688 → 49,687 (1 dropped)
   * orders: 3,421,083 → 3,346,083 (75,000 dropped)
   * order_products: 33,819,106 → 33,819,106 ✓

2. **Type Conversions**: `aisle_id` and `department_id` successfully cast to INT ✓

3. **Primary Key Uniqueness**: Zero duplicates in all ID columns ✓

4. **Referential Integrity**:
   * products → aisles: 0 orphans ✓
   * products → departments: 0 orphans ✓
   * order_products → orders: 0 orphans ✓
   * order_products → products: **3 orphans** ⚠

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

**Data Quality Checks**:

1. **Table Row Counts**:
   * dim_product: 49,687 ✓
   * dim_order: 3,346,083 ✓
   * fact_order_product: 33,819,103 ✓

2. **Primary Key Constraints**:
   * dim_product.product_id: No NULLs, No duplicates ✓
   * dim_order.order_id: No NULLs, No duplicates ✓
   * fact_order_product (order_id, add_to_cart_order): No NULLs, No duplicates ✓

3. **Foreign Key Constraints**:
   * fact → dim_product: 0 orphans (3 filtered upstream) ✓
   * fact → dim_order: 0 orphans ✓

4. **Unity Catalog Constraints**: All PK/FK constraints successfully applied ✓

---

## 6. Business Analytics

The star schema supports analytical queries answering business questions:

### Business Question 1: Product & Department Popularity

**Query Pattern**: Aggregate fact table by product dimension attributes

```sql
SELECT 
  dp.department_name,
  dp.product_name,
  COUNT(*) AS purchase_count,
  COUNT(DISTINCT f.order_id) AS order_count,
  COUNT(DISTINCT do.user_id) AS customer_count,
  ROUND(AVG(CAST(f.reordered AS INT)) * 100, 2) AS reorder_rate_pct
FROM workspace.instacart_gold.fact_order_product f
INNER JOIN workspace.instacart_gold.dim_product dp ON f.product_id = dp.product_id
INNER JOIN workspace.instacart_gold.dim_order do ON f.order_id = do.order_id
GROUP BY dp.department_name, dp.product_name
ORDER BY purchase_count DESC;
```

### Business Question 2: Temporal Purchase Patterns

**Query Pattern**: Aggregate fact table by temporal dimensions

```sql
SELECT 
  do.day_of_week_name,
  do.order_hour_of_day,
  COUNT(DISTINCT f.order_id) AS total_orders,
  COUNT(*) AS total_items,
  ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT f.order_id), 2) AS avg_items_per_order
FROM workspace.instacart_gold.fact_order_product f
INNER JOIN workspace.instacart_gold.dim_order do ON f.order_id = do.order_id
GROUP BY do.day_of_week_name, do.order_hour_of_day
ORDER BY do.day_of_week_name, do.order_hour_of_day;
```

### Business Question 3: Product Reorder Behavior

**Query Pattern**: Aggregate reordered measure by product

```sql
SELECT 
  dp.product_name,
  COUNT(*) AS total_purchases,
  SUM(CAST(f.reordered AS INT)) AS reorder_count,
  ROUND(SUM(CAST(f.reordered AS INT)) * 100.0 / COUNT(*), 2) AS reorder_rate_pct,
  COUNT(DISTINCT do.user_id) AS unique_customers
FROM workspace.instacart_gold.fact_order_product f
INNER JOIN workspace.instacart_gold.dim_product dp ON f.product_id = dp.product_id
INNER JOIN workspace.instacart_gold.dim_order do ON f.order_id = do.order_id
GROUP BY dp.product_name
HAVING COUNT(*) >= 100
ORDER BY reorder_rate_pct DESC;
```

---

## 7. Dashboard

**Dashboard Name**: Instacart Customer & Purchase Analytics

**Dashboard Type**: Lakeview Dashboard (AI/BI)

**Data Sources**: 
* Primary: `workspace.instacart_gold.fact_order_product`
* Dimensions: `dim_product`, `dim_order`
* Legacy analytics tables in `workspace.default` (for backward compatibility)

**Dashboard Components**:

1. **KPI Cards**:
   * Total Orders
   * Unique Customers
   * Total Products Purchased
   * Reorder Rate

2. **Product Analysis**:
   * Top 10 Products by Purchase Volume
   * Top 10 Departments by Purchase Volume
   * Top 20 Products by Reorder Rate
   * Department Loyalty (avg reorder rate by department)

3. **Temporal Analysis**:
   * Order Volume by Day of Week (bar chart)
   * Order Volume by Hour of Day (line chart)
   * Purchase Heatmap: Day × Hour (pivot table)

4. **Reorder Analysis**:
   * Reorder Distribution (pie chart: first-time vs. reordered)

**Performance**: All dashboard queries < 1 second (leveraging Delta Lake + serverless compute)

---

## 8. Data Lineage Summary

```
Source CSV                  → Bronze                        → Silver                    → Gold
────────────────────────────────────────────────────────────────────────────────────────────────────────
aisles.csv                  → bronze_aisles                 → silver_aisles             → dim_product.aisle_*
departments.csv             → bronze_departments            → silver_departments        → dim_product.department_*
products.csv                → bronze_products               → silver_products           → dim_product
orders.csv                  → bronze_orders                 → silver_orders             → dim_order
order_products__prior.csv   → bronze_order_products_prior   → silver_order_products     → fact_order_product
order_products__train.csv   → bronze_order_products_train  →   (union with prior)      →   (same fact)
```

**Key Transformations**:
* **Bronze → Silver**: Type fixes (STRING → INT), NULL filtering, UNION datasets
* **Silver → Gold**: Denormalization, derived attributes (day names, time buckets), Unity Catalog constraints

---

## 9. Performance Metrics

| Layer | Execution Time | Records Processed |
|-------|----------------|-------------------|
| **Bronze** | ~2 minutes | 37.3M rows |
| **Silver** | ~3 minutes | 37.2M rows (75K filtered) |
| **Gold** | ~5 minutes | 33.8M fact rows + 3.4M dimension rows |
| **End-to-End** | ~10 minutes | Full pipeline |

**Compute**: Databricks Serverless SQL Warehouse

**Storage**: Delta Lake format, Unity Catalog managed

---

## 10. Technical Stack

* **Platform**: Databricks (AWS)
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

**3 Orphan Products**
* **Description**: `silver_order_products` contains 3 product IDs not in `silver_products`
* **Impact**: 3 rows filtered from Gold layer during FK validation
* **Status**: Documented; upstream source data issue

**75,000 Orders Dropped**
* **Description**: Orders with NULL `user_id` or `order_id`
* **Impact**: ~2.2% of orders excluded from Silver layer
* **Status**: Expected behavior; data quality filter

### Design Decisions

**No Separate Customer Dimension**
* **Decision**: Customer attributes embedded in `dim_order`
* **Reason**: Simplified star schema for initial implementation
* **Future**: May split into `dim_customer` in Phase 2

**No Analytics Tables in Gold Schema**
* **Current State**: Analytics queries run directly against fact/dimension tables
* **Legacy**: Pre-aggregated tables exist in `workspace.default` (old implementation)
* **Future**: May add materialized aggregate tables for dashboard performance

---

## 12. Future Enhancements

### Phase 2
* Add `dim_date` dimension with fiscal calendar
* Split `dim_order` into separate `dim_customer` table
* Create aggregate fact tables for dashboard performance
* Implement SCD Type 2 for product price tracking

### Phase 3
* Automate pipeline with Databricks Jobs/Workflows
* Add data quality monitoring
* Implement incremental loads
* Real-time streaming ingestion (Kafka → Bronze)

---

**Last Updated**: 2026-09-04  
**Architecture Version**: 1.0 (workspace.instacart_gold implementation)  
**Maintained By**: FTW Data Engineering Batch 12
