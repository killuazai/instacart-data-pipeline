# Architecture Documentation

**Engineer Instacart — Data Pipeline Architecture**

---

## 1. System Overview

The Instacart data pipeline follows the **Medallion Architecture** pattern with four distinct layers:

```
SOURCE (CSV Files)
    ↓
BRONZE (Raw Ingestion)
    ↓
SILVER (Cleaned & Standardized)
    ↓
GOLD (Dimensional Model + Business Analytics)
    ↓
BUSINESS ANALYTICS DASHBOARD
```

### Architecture Principles

1. **Separation of Concerns**: Each layer has a distinct purpose and responsibility
2. **Immutability**: Bronze layer preserves raw data; transformations are additive
3. **Incremental Refinement**: Data quality improves progressively through each layer
4. **Auditability**: Metadata (loaded_at, source_system) tracks data lineage
5. **Performance Optimization**: Gold layer pre-aggregates metrics for dashboard consumption

---

## 2. Source Layer

The source data consists of six CSV files provided by Instacart, representing transactional and reference data.

### Source Datasets

#### 2.1 `aisles.csv`
* **Purpose**: Reference data for product aisle classifications
* **Row Count**: 134 aisles
* **Schema**: aisle_id (INT), aisle (STRING)
* **Grain**: One row per aisle
* **Example**: "fresh fruits", "packaged cheese", "energy granola bars"

#### 2.2 `departments.csv`
* **Purpose**: Reference data for product department classifications
* **Row Count**: 21 departments
* **Schema**: department_id (INT), department (STRING)
* **Grain**: One row per department
* **Example**: "produce", "dairy eggs", "snacks"

#### 2.3 `products.csv`
* **Purpose**: Product catalog with hierarchical classification
* **Row Count**: 49,688 products
* **Schema**: product_id (INT), product_name (STRING), aisle_id (STRING), department_id (STRING)
* **Grain**: One row per product
* **Note**: aisle_id and department_id are incorrectly typed as STRING in source

#### 2.4 `orders.csv`
* **Purpose**: Order header information including temporal attributes
* **Row Count**: 3,421,083 orders
* **Schema**: 
  * order_id (INT)
  * user_id (INT)
  * eval_set (STRING) — 'prior', 'train', or 'test'
  * order_number (INT) — sequence number for the customer
  * order_dow (INT) — day of week (0=Sunday)
  * order_hour_of_day (INT) — hour (0-23)
  * days_since_prior_order (DOUBLE) — NULL for first order
* **Grain**: One row per order

#### 2.5 `order_products__prior.csv`
* **Purpose**: Order line items for 'prior' orders (historical training data)
* **Row Count**: 32,434,489 line items
* **Schema**: order_id (INT), product_id (INT), add_to_cart_order (INT), reordered (INT)
* **Grain**: One row per product per order

#### 2.6 `order_products__train.csv`
* **Purpose**: Order line items for 'train' orders (labeled training set)
* **Row Count**: 1,384,617 line items
* **Schema**: order_id (INT), product_id (INT), add_to_cart_order (INT), reordered (INT)
* **Grain**: One row per product per order

---

## 3. Bronze Layer

**Purpose**: Ingest raw data from source CSV files with minimal transformation. Preserve data integrity and enable downstream troubleshooting.

**Implementation**: SQL `read_files()` function with CSV format

**Owner**: Nadine

### Bronze Tables

#### 3.1 `bronze_aisles`
* **Source**: aisles.csv
* **Row Count**: 134
* **Schema**: aisle_id (INT), aisle (STRING), _rescued_data (STRING)
* **Grain**: One row per aisle
* **Data Quality**: No rescued data (all NULL)

#### 3.2 `bronze_departments`
* **Source**: departments.csv
* **Row Count**: 21
* **Schema**: department_id (INT), department (STRING), _rescued_data (STRING)
* **Grain**: One row per department
* **Data Quality**: No rescued data (all NULL)

#### 3.3 `bronze_products`
* **Source**: products.csv
* **Row Count**: 49,688
* **Schema**: product_id (INT), product_name (STRING), aisle_id (STRING), department_id (STRING), _rescued_data (STRING)
* **Grain**: One row per product
* **Data Quality**: 
  * No rescued data (all NULL)
  * **Issue**: aisle_id and department_id are STRING (should be INT)

#### 3.4 `bronze_orders`
* **Source**: orders.csv
* **Row Count**: 3,421,083
* **Schema**: order_id (INT), user_id (INT), eval_set (STRING), order_number (INT), order_dow (INT), order_hour_of_day (INT), days_since_prior_order (DOUBLE), _rescued_data (STRING)
* **Grain**: One row per order
* **Data Quality**: No rescued data (all NULL)

#### 3.5 `bronze_order_products_prior`
* **Source**: order_products__prior.csv
* **Row Count**: 32,434,489
* **Schema**: order_id (INT), product_id (INT), add_to_cart_order (INT), reordered (INT), _rescued_data (STRING)
* **Grain**: One row per product per order
* **Data Quality**: No rescued data (all NULL)

#### 3.6 `bronze_order_products_train`
* **Source**: order_products__train.csv
* **Row Count**: 1,384,617
* **Schema**: order_id (INT), product_id (INT), add_to_cart_order (INT), reordered (INT), _rescued_data (STRING)
* **Grain**: One row per product per order
* **Data Quality**: No rescued data (all NULL)

### Bronze Layer Characteristics

* **Preservation**: All source columns retained
* **Metadata**: `_rescued_data` column for malformed records (validated as all NULL)
* **No Transformations**: Data types match source (even incorrect ones)
* **No Filtering**: All rows preserved

---

## 4. Silver Layer

**Purpose**: Clean, standardize, and validate Bronze data. Apply type conversions, filter invalid records, and prepare data for dimensional modeling.

**Implementation**: SQL CREATE OR REPLACE TABLE with data quality checks

**Owner**: Ina

### Silver Tables

#### 4.1 `silver_aisles`
* **Source**: bronze_aisles
* **Row Count**: 134 (0 dropped)
* **Schema**: aisle_id (INT), aisle (STRING), loaded_at (TIMESTAMP)
* **Transformations**:
  * Drop `_rescued_data` (validated as all NULL)
  * Filter NULL values in aisle_id and aisle
  * Add `loaded_at` timestamp
* **Grain**: One row per aisle

#### 4.2 `silver_departments`
* **Source**: bronze_departments
* **Row Count**: 21 (0 dropped)
* **Schema**: department_id (INT), department (STRING), loaded_at (TIMESTAMP)
* **Transformations**:
  * Drop `_rescued_data`
  * Filter NULL values in department_id and department
  * Add `loaded_at` timestamp
* **Grain**: One row per department

#### 4.3 `silver_products`
* **Source**: bronze_products
* **Row Count**: 49,687 (1 dropped)
* **Schema**: product_id (INT), product_name (STRING), aisle_id (INT), department_id (INT), loaded_at (TIMESTAMP)
* **Transformations**:
  * **CAST aisle_id from STRING to INT**
  * **CAST department_id from STRING to INT**
  * Drop `_rescued_data`
  * Filter NULL values in product_id, product_name, aisle_id, department_id
  * Add `loaded_at` timestamp
* **Grain**: One row per product
* **Data Quality**: 1 row dropped due to NULL filtering

#### 4.4 `silver_orders`
* **Source**: bronze_orders
* **Row Count**: 3,346,083 (75,000 dropped)
* **Schema**: order_id (INT), user_id (INT), eval_set (STRING), order_number (INT), order_dow (INT), order_hour_of_day (INT), days_since_prior_order (DOUBLE), loaded_at (TIMESTAMP)
* **Transformations**:
  * Drop `_rescued_data`
  * Filter NULL values in order_id and user_id
  * **Preserve NULL in days_since_prior_order** (intentional for first orders)
  * Add `loaded_at` timestamp
* **Grain**: One row per order
* **Data Quality**: 75,000 rows dropped due to NULL filtering in required fields

#### 4.5 `silver_order_products`
* **Source**: bronze_order_products_prior + bronze_order_products_train (UNION)
* **Row Count**: 33,819,106 (0 dropped)
* **Schema**: order_id (INT), product_id (INT), add_to_cart_order (INT), reordered (INT), source_system (STRING), loaded_at (TIMESTAMP)
* **Transformations**:
  * **UNION** prior and train datasets
  * Add `source_system` column ('prior' or 'train') to track origin
  * Drop `_rescued_data`
  * Filter NULL values in order_id, product_id, add_to_cart_order, reordered
  * Add `loaded_at` timestamp
* **Grain**: One row per product per order
* **Data Quality**: 0 rows dropped

### Silver Layer Validation

**Data Quality Checks** (implemented by Ina):

1. **Row Count Reconciliation**:
   * departments: 21 → 21 (0 dropped)
   * aisles: 134 → 134 (0 dropped)
   * products: 49,688 → 49,687 (1 dropped)
   * orders: 3,421,083 → 3,346,083 (75,000 dropped)
   * order_products: 33,819,106 → 33,819,106 (0 dropped)

2. **NULL Checks**: 0 NULLs in required fields

3. **Primary Key Uniqueness**: 0 duplicates

4. **Referential Integrity**:
   * products → aisles: 0 orphans
   * products → departments: 0 orphans
   * order_products → orders: 0 orphans
   * order_products → products: **3 orphans** (documented data quality issue)

5. **Data Type Verification**: aisle_id and department_id successfully cast to INT

---

## 5. Gold Layer

**Purpose**: Build dimensional star schema optimized for analytics. Create pre-aggregated business analytics tables for dashboard consumption.

**Implementation**: SQL CREATE OR REPLACE TABLE with star schema design

**Owner**: Cath

### 5.1 Dimensional Model

#### Fact Table: `fact_order_items`

* **Source**: silver_order_products + silver_orders + silver_products
* **Row Count**: 33,819,103 (3 rows dropped due to orphan products)
* **Grain**: **One row per product per order** (order line item)
* **Schema**:
  * `order_item_key` (BIGINT) — Surrogate key (PK)
  * `order_key` (INT) — FK to dim_orders
  * `product_key` (INT) — FK to dim_products
  * `customer_key` (INT) — FK to dim_customers
  * `add_to_cart_order` (INT) — Measure
  * `is_reordered` (INT) — Measure (0 or 1)
  * `source_system` (STRING) — Lineage ('prior' or 'train')
  * `loaded_at` (TIMESTAMP) — Metadata

* **Keys**:
  * Primary Key: `order_item_key`
  * Composite Natural Key: (order_key, product_key)
  * Foreign Keys: order_key, product_key, customer_key

* **Measures**:
  * `add_to_cart_order`: Sequence of product addition to cart
  * `is_reordered`: Binary indicator of repeat purchase

#### Dimension Table: `dim_products`

* **Source**: silver_products + silver_aisles + silver_departments
* **Row Count**: 49,687
* **Grain**: One row per product
* **Schema**:
  * `product_key` (INT) — PK (= product_id)
  * `product_id` (INT) — Natural key
  * `product_name` (STRING)
  * `aisle_id` (INT)
  * `aisle_name` (STRING)
  * `department_id` (INT)
  * `department_name` (STRING)
  * `product_hierarchy` (STRING) — Denormalized: "department / aisle / product"
  * `loaded_at` (TIMESTAMP)

* **Purpose**: Product dimension with denormalized hierarchy for filtering and drill-down

#### Dimension Table: `dim_customers`

* **Source**: silver_orders (aggregated by user_id)
* **Row Count**: 206,209
* **Grain**: One row per customer
* **Schema**:
  * `customer_key` (INT) — PK (= user_id)
  * `user_id` (INT) — Natural key
  * `first_order_number` (INT) — Always 1
  * `total_orders` (INT) — Max order_number for the customer
  * `total_order_count` (BIGINT) — COUNT(DISTINCT order_id)
  * `avg_days_between_orders` (DOUBLE) — Average days_since_prior_order
  * `loaded_at` (TIMESTAMP)

* **Purpose**: Customer dimension with pre-aggregated behavioral metrics

#### Dimension Table: `dim_orders`

* **Source**: silver_orders
* **Row Count**: 3,346,083
* **Grain**: One row per order
* **Schema**:
  * `order_key` (INT) — PK (= order_id)
  * `order_id` (INT) — Natural key
  * `user_id` (INT) — Customer reference
  * `order_number` (INT) — Sequence for customer
  * `order_dow` (INT) — Day of week (0-6)
  * `day_of_week_name` (STRING) — 'Sunday', 'Monday', etc.
  * `order_hour_of_day` (INT) — Hour (0-23)
  * `time_of_day_bucket` (STRING) — 'Morning', 'Afternoon', 'Evening', 'Night'
  * `days_since_prior_order` (DOUBLE) — NULL for first order
  * `loaded_at` (TIMESTAMP)

* **Purpose**: Order dimension with temporal attributes for time-based analysis

### 5.2 Business Analytics Tables

Pre-aggregated tables optimized for dashboard consumption.

#### `gold_product_popularity`

* **Source**: fact_order_items + dim_products
* **Row Count**: 49,684 (3 products excluded due to low volume)
* **Grain**: One row per product
* **Purpose**: Answer BQ1 — Which products and departments are purchased most frequently?
* **Metrics**:
  * total_orders: COUNT(*)
  * unique_customers: COUNT(DISTINCT customer_key)
  * reorder_rate_pct: % of purchases that are reorders
  * avg_products_per_order: Average basket size

#### `gold_temporal_patterns`

* **Source**: fact_order_items + dim_orders
* **Row Count**: 168 (7 days × 24 hours)
* **Grain**: One row per day-of-week + hour-of-day combination
* **Purpose**: Answer BQ2 — How does purchasing behavior change by day and hour?
* **Metrics**:
  * total_orders: COUNT(DISTINCT order_key)
  * total_items: COUNT(*)
  * avg_items_per_order: total_items / total_orders
  * unique_customers: COUNT(DISTINCT customer_key)

#### `gold_reorder_behavior`

* **Source**: fact_order_items + dim_products
* **Row Count**: 42,987 (products with ≥ 10 purchases)
* **Grain**: One row per product
* **Purpose**: Answer BQ3 — Which products have the highest reorder behavior?
* **Metrics**:
  * total_purchases: COUNT(*)
  * reorder_count: SUM(is_reordered)
  * first_time_purchase_count: total_purchases - reorder_count
  * reorder_rate_pct: (reorder_count / total_purchases) × 100
  * reorder_rank: RANK by reorder_rate (for products with ≥ 100 purchases)
  * unique_customers: COUNT(DISTINCT customer_key)

#### `gold_basket_pairs`

* **Source**: fact_order_items self-join + dim_products
* **Row Count**: 1,000 (top 1,000 pairs)
* **Grain**: One row per product pair (A, B where A < B)
* **Purpose**: Answer BQ4 — What are the most common product pairs purchased together?
* **Metrics**:
  * orders_with_both: COUNT(DISTINCT order_key)
  * customers_buying_both: COUNT(DISTINCT customer_key)
  * pair_frequency_pct: % of orders containing both products
* **Threshold**: Minimum 100 co-occurrences

### Gold Layer Validation

**Data Quality Checks** (implemented by Cath):

1. **Row Counts**:
   * dim_products: 49,687
   * dim_customers: 206,209
   * dim_orders: 3,346,083
   * fact_order_items: 33,819,103
   * gold_product_popularity: 49,684
   * gold_temporal_patterns: 168
   * gold_reorder_behavior: 42,987
   * gold_basket_pairs: 1,000

2. **Fact-to-Dimension Relationships**: 0 orphans in all foreign keys

3. **Fact Table Grain**: 0 duplicates at (order_key, product_key) level

4. **Silver to Gold Reconciliation**: 3-row difference due to orphan products filtered

---

## 6. Business Analytics Layer

The Business Analytics Dashboard is the consumption layer built on top of Gold tables.

**Owner**: Maeve

### Dashboard Data Sources

* **Dimensional Model**: fact_order_items + dimension tables for flexible ad-hoc queries
* **Pre-aggregated Tables**: gold_product_popularity, gold_temporal_patterns, gold_reorder_behavior, gold_basket_pairs for performance

### Dashboard Capabilities

* **Product Insights**: Top products and departments by order volume, reorder rates
* **Temporal Insights**: Heatmaps showing order patterns by day/hour
* **Customer Insights**: Reorder behavior, basket size, purchase frequency
* **Cross-Sell Insights**: Product pairs frequently bought together

### Key Performance Indicators

* Total Orders: 3.3M
* Total Customers: 206K
* Total Products: 49.7K
* Avg Reorder Rate: ~40-85% (varies by product/department)
* Most Popular Product: Banana (491K orders)
* Peak Order Time: Sunday 2-3 PM

---

## 7. Data Flow Summary

### Bronze → Silver

```
SOURCE (CSV) → Bronze (Raw) → Silver (Cleaned)

Transformations:
* Drop _rescued_data
* CAST aisle_id, department_id to INT
* Filter NULL values
* UNION prior + train → silver_order_products
* Add loaded_at, source_system

Validation:
* Row count reconciliation
* NULL checks
* Primary key uniqueness
* Referential integrity
* Data type verification
```

### Silver → Gold

```
Silver (Cleaned) → Gold (Dimensional + Analytics)

Transformations:
* Build star schema (fact + dimensions)
* Add surrogate keys
* Denormalize dimensions (product hierarchy, day names)
* Add calculated fields (time buckets, hierarchies)
* Pre-aggregate business metrics

Validation:
* Fact-to-dimension relationships
* Fact table grain uniqueness
* Silver-to-Gold reconciliation
```

---

## 8. Architectural Decisions

See [Engineering Decisions](decisions.md) for detailed rationale on:

* Why we preserve _rescued_data in Bronze
* Why we union prior + train in Silver
* Why we use star schema in Gold
* Why we pre-aggregate business analytics tables
* How we handle orphan products
* How we handle NULL days_since_prior_order

---

**Last Updated**: September 2, 2026  
**Document Owner**: Tina (Cristina)  
**Project**: Engineer Instacart