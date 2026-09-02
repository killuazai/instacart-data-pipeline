# Data Dictionary

**Engineer Instacart — Comprehensive Column Definitions**

---

## Bronze Layer Tables

Raw ingestion layer preserving source data structure.

### `bronze_aisles`

**Row Count**: 134  
**Grain**: One row per aisle

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `aisle_id` | INT | Unique identifier for aisle | PK |
| `aisle` | STRING | Aisle name (e.g., "fresh fruits", "packaged cheese") | Attribute |
| `_rescued_data` | STRING | Malformed CSV records (validated as all NULL) | Data Quality |

---

### `bronze_departments`

**Row Count**: 21  
**Grain**: One row per department

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `department_id` | INT | Unique identifier for department | PK |
| `department` | STRING | Department name (e.g., "produce", "dairy eggs", "snacks") | Attribute |
| `_rescued_data` | STRING | Malformed CSV records (validated as all NULL) | Data Quality |

---

### `bronze_products`

**Row Count**: 49,688  
**Grain**: One row per product

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `product_id` | INT | Unique identifier for product | PK |
| `product_name` | STRING | Full product name (e.g., "Organic Hass Avocado") | Attribute |
| `aisle_id` | **STRING** | Aisle identifier (incorrectly typed in source) | FK (should be INT) |
| `department_id` | **STRING** | Department identifier (incorrectly typed in source) | FK (should be INT) |
| `_rescued_data` | STRING | Malformed CSV records (validated as all NULL) | Data Quality |

**Data Quality Issue**: `aisle_id` and `department_id` are STRING in source (should be INT). Fixed in Silver layer.

---

### `bronze_orders`

**Row Count**: 3,421,083  
**Grain**: One row per order

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `order_id` | INT | Unique identifier for order | PK |
| `user_id` | INT | Customer who placed the order | FK |
| `eval_set` | STRING | Dataset split: 'prior', 'train', or 'test' | Metadata |
| `order_number` | INT | Sequence number for customer (1, 2, 3...) | Attribute |
| `order_dow` | INT | Day of week (0=Sunday, 1=Monday, ..., 6=Saturday) | Attribute |
| `order_hour_of_day` | INT | Hour of order placement (0-23) | Attribute |
| `days_since_prior_order` | DOUBLE | Days elapsed since customer's previous order (NULL for first order) | Attribute |
| `_rescued_data` | STRING | Malformed CSV records (validated as all NULL) | Data Quality |

---

### `bronze_order_products_prior`

**Row Count**: 32,434,489  
**Grain**: One row per product per order (order line item)

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `order_id` | INT | Order identifier | PK (Composite) |
| `product_id` | INT | Product identifier | PK (Composite) |
| `add_to_cart_order` | INT | Sequence of product added to cart (1, 2, 3...) | Attribute |
| `reordered` | INT | Binary flag: 1 = reordered, 0 = first purchase | Attribute |
| `_rescued_data` | STRING | Malformed CSV records (validated as all NULL) | Data Quality |

**Primary Key**: (`order_id`, `product_id`)

---

### `bronze_order_products_train`

**Row Count**: 1,384,617  
**Grain**: One row per product per order (order line item)

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `order_id` | INT | Order identifier | PK (Composite) |
| `product_id` | INT | Product identifier | PK (Composite) |
| `add_to_cart_order` | INT | Sequence of product added to cart (1, 2, 3...) | Attribute |
| `reordered` | INT | Binary flag: 1 = reordered, 0 = first purchase | Attribute |
| `_rescued_data` | STRING | Malformed CSV records (validated as all NULL) | Data Quality |

**Primary Key**: (`order_id`, `product_id`)

---

## Silver Layer Tables

Cleaned and standardized data with data quality validation.

### `silver_aisles`

**Row Count**: 134 (0 dropped)  
**Grain**: One row per aisle

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `aisle_id` | INT | Unique identifier for aisle | PK |
| `aisle` | STRING | Aisle name (e.g., "fresh fruits", "packaged cheese") | Attribute |
| `loaded_at` | TIMESTAMP | ETL timestamp indicating when record was loaded | Metadata |

**Transformations**: Dropped `_rescued_data`, filtered NULLs, added `loaded_at`

---

### `silver_departments`

**Row Count**: 21 (0 dropped)  
**Grain**: One row per department

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `department_id` | INT | Unique identifier for department | PK |
| `department` | STRING | Department name (e.g., "produce", "dairy eggs", "snacks") | Attribute |
| `loaded_at` | TIMESTAMP | ETL timestamp indicating when record was loaded | Metadata |

**Transformations**: Dropped `_rescued_data`, filtered NULLs, added `loaded_at`

---

### `silver_products`

**Row Count**: 49,687 (1 dropped)  
**Grain**: One row per product

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `product_id` | INT | Unique identifier for product | PK |
| `product_name` | STRING | Full product name (e.g., "Organic Hass Avocado") | Attribute |
| `aisle_id` | **INT** | Aisle identifier (CAST from STRING) | FK to silver_aisles |
| `department_id` | **INT** | Department identifier (CAST from STRING) | FK to silver_departments |
| `loaded_at` | TIMESTAMP | ETL timestamp indicating when record was loaded | Metadata |

**Transformations**: CAST aisle_id and department_id to INT, dropped `_rescued_data`, filtered NULLs, added `loaded_at`

---

### `silver_orders`

**Row Count**: 3,346,083 (75,000 dropped)  
**Grain**: One row per order

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `order_id` | INT | Unique identifier for order | PK |
| `user_id` | INT | Customer who placed the order | FK |
| `eval_set` | STRING | Dataset split: 'prior', 'train', or 'test' | Metadata |
| `order_number` | INT | Sequence number for customer (1, 2, 3...) | Attribute |
| `order_dow` | INT | Day of week (0=Sunday, 1=Monday, ..., 6=Saturday) | Attribute |
| `order_hour_of_day` | INT | Hour of order placement (0-23) | Attribute |
| `days_since_prior_order` | DOUBLE | Days elapsed since customer's previous order (NULL intentionally preserved for first order) | Attribute |
| `loaded_at` | TIMESTAMP | ETL timestamp indicating when record was loaded | Metadata |

**Transformations**: Dropped `_rescued_data`, filtered NULLs in order_id/user_id, preserved NULL in days_since_prior_order, added `loaded_at`

**Data Quality**: 75,000 rows dropped due to NULL filtering in required fields

---

### `silver_order_products`

**Row Count**: 33,819,106 (0 dropped)  
**Grain**: One row per product per order (order line item)

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `order_id` | INT | Order identifier | PK (Composite) |
| `product_id` | INT | Product identifier | PK (Composite) |
| `add_to_cart_order` | INT | Sequence of product added to cart (1, 2, 3...) | Attribute |
| `reordered` | INT | Binary flag: 1 = reordered, 0 = first purchase | Attribute |
| `source_system` | STRING | Origin dataset: 'prior' or 'train' | Lineage Metadata |
| `loaded_at` | TIMESTAMP | ETL timestamp indicating when record was loaded | Metadata |

**Transformations**: UNION of bronze_order_products_prior and bronze_order_products_train, added `source_system`, dropped `_rescued_data`, filtered NULLs, added `loaded_at`

**Primary Key**: (`order_id`, `product_id`)

**Referential Integrity Issue**: 3 orphan products (product_id does not exist in silver_products)

---

## Gold Layer Tables

Dimensional model (star schema) and pre-aggregated business analytics tables.

### Dimensional Model

#### `fact_order_items`

**Row Count**: 33,819,103 (3 dropped due to orphan products)  
**Grain**: One row per product per order (order line item)

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `order_item_key` | BIGINT | Surrogate key (auto-generated sequential ID) | PK |
| `order_key` | INT | Order identifier | FK to dim_orders |
| `product_key` | INT | Product identifier | FK to dim_products |
| `customer_key` | INT | Customer identifier | FK to dim_customers |
| `add_to_cart_order` | INT | Sequence of product added to cart (1=first, 2=second, etc.) | Measure (Semi-Additive) |
| `is_reordered` | INT | Binary flag: 1 = customer reordered this product, 0 = first-time purchase | Measure (Additive) |
| `source_system` | STRING | Origin dataset: 'prior' or 'train' | Lineage Metadata |
| `loaded_at` | TIMESTAMP | ETL timestamp | Metadata |

**Primary Key**: `order_item_key`  
**Natural Key**: (`order_key`, `product_key`)  
**Foreign Keys**: `order_key`, `product_key`, `customer_key`

---

#### `dim_products`

**Row Count**: 49,687  
**Grain**: One row per product

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `product_key` | INT | Primary key (= product_id) | PK |
| `product_id` | INT | Natural key from source system | Natural Key |
| `product_name` | STRING | Full product name (e.g., "Organic Hass Avocado") | Attribute |
| `aisle_id` | INT | Aisle identifier | Attribute |
| `aisle_name` | STRING | Aisle name (e.g., "fresh fruits") | Attribute |
| `department_id` | INT | Department identifier | Attribute |
| `department_name` | STRING | Department name (e.g., "produce") | Attribute |
| `product_hierarchy` | STRING | Full hierarchy: "department / aisle / product" (e.g., "produce / fresh fruits / Organic Hass Avocado") | Derived Attribute |
| `loaded_at` | TIMESTAMP | ETL timestamp | Metadata |

**Hierarchy**: Department (21) → Aisle (134) → Product (49,687)

---

#### `dim_customers`

**Row Count**: 206,209  
**Grain**: One row per customer

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `customer_key` | INT | Primary key (= user_id) | PK |
| `user_id` | INT | Natural key from source system | Natural Key |
| `first_order_number` | INT | Minimum order_number for customer (always 1) | Attribute |
| `total_orders` | INT | Maximum order_number for customer (lifetime order count) | Pre-Aggregated Metric |
| `total_order_count` | BIGINT | COUNT(DISTINCT order_id) for customer | Pre-Aggregated Metric |
| `avg_days_between_orders` | DOUBLE | Average days_since_prior_order for customer | Pre-Aggregated Metric |
| `loaded_at` | TIMESTAMP | ETL timestamp | Metadata |

**Pre-Aggregated Metrics**: Customer lifetime metrics computed during dimension build

---

#### `dim_orders`

**Row Count**: 3,346,083  
**Grain**: One row per order

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `order_key` | INT | Primary key (= order_id) | PK |
| `order_id` | INT | Natural key from source system | Natural Key |
| `user_id` | INT | Customer who placed the order | Attribute |
| `order_number` | INT | Sequence number for customer (1, 2, 3...) | Attribute |
| `order_dow` | INT | Day of week (0=Sunday, 1=Monday, ..., 6=Saturday) | Attribute |
| `day_of_week_name` | STRING | Human-readable day name: "Sunday", "Monday", ..., "Saturday" | Derived Attribute |
| `order_hour_of_day` | INT | Hour of order placement (0-23) | Attribute |
| `time_of_day_bucket` | STRING | Time bucket: "Morning" (5-11), "Afternoon" (12-16), "Evening" (17-21), "Night" (22-4) | Derived Attribute |
| `days_since_prior_order` | DOUBLE | Days elapsed since customer's previous order (NULL for first order) | Attribute |
| `loaded_at` | TIMESTAMP | ETL timestamp | Metadata |

**Derived Attributes**: `day_of_week_name` and `time_of_day_bucket` computed from temporal fields

---

### Business Analytics Tables

Pre-aggregated tables optimized for dashboard consumption.

#### `gold_product_popularity`

**Row Count**: 49,684  
**Grain**: One row per product  
**Purpose**: Answer BQ1 — Which products and departments are purchased most frequently?

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `department_name` | STRING | Department name | Dimension |
| `aisle_name` | STRING | Aisle name | Dimension |
| `product_name` | STRING | Product name | Dimension |
| `product_id` | INT | Product identifier | Dimension |
| `total_orders` | BIGINT | Total number of orders containing this product | Metric |
| `unique_customers` | BIGINT | COUNT(DISTINCT customer_key) | Metric |
| `reorder_rate_pct` | DECIMAL(27,2) | Percentage of purchases that are reorders | Metric |
| `avg_products_per_order` | DOUBLE | [TO CONFIRM — not visible in sample] | Metric |

**Sorting**: Pre-sorted by `total_orders DESC`

---

#### `gold_temporal_patterns`

**Row Count**: 168 (7 days × 24 hours)  
**Grain**: One row per (day_of_week, hour_of_day) combination  
**Purpose**: Answer BQ2 — How does purchasing behavior change by day and hour?

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `day_of_week_name` | STRING | Day name ("Sunday", "Monday", etc.) | Dimension |
| `order_dow` | INT | Day of week numeric (0-6) | Dimension |
| `order_hour_of_day` | INT | Hour (0-23) | Dimension |
| `time_of_day_bucket` | STRING | Time bucket ("Morning", "Afternoon", "Evening", "Night") | Dimension |
| `total_orders` | BIGINT | COUNT(DISTINCT order_key) | Metric |
| `total_items` | BIGINT | COUNT(*) of order items | Metric |
| `avg_items_per_order` | DOUBLE | total_items / total_orders | Metric |
| `unique_customers` | BIGINT | COUNT(DISTINCT customer_key) | Metric |

**Use Case**: Heatmap visualization for order patterns

---

#### `gold_reorder_behavior`

**Row Count**: 42,987 (products with ≥ 10 purchases)  
**Grain**: One row per product  
**Purpose**: Answer BQ3 — Which products have the highest reorder behavior?

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `department_name` | STRING | Department name | Dimension |
| `aisle_name` | STRING | Aisle name | Dimension |
| `product_name` | STRING | Product name | Dimension |
| `product_id` | INT | Product identifier | Dimension |
| `total_purchases` | BIGINT | Total number of purchases (order line items) | Metric |
| `reorder_count` | BIGINT | SUM(is_reordered) | Metric |
| `first_time_purchase_count` | BIGINT | total_purchases - reorder_count | Metric |
| `reorder_rate_pct` | DECIMAL(27,2) | (reorder_count / total_purchases) × 100 | Metric |
| `unique_customers` | BIGINT | COUNT(DISTINCT customer_key) | Metric |
| `reorder_rank` | INT | RANK by reorder_rate (NULL if < 100 purchases) | Derived Metric |

**Filters**: Minimum 10 purchases per product; reorder_rank computed only for products with ≥ 100 purchases

---

#### `gold_basket_pairs`

**Row Count**: 1,000 (top 1,000 pairs)  
**Grain**: One row per product pair (A, B where A < B)  
**Purpose**: Answer BQ4 — What are the most common product pairs purchased together?

| Column | Data Type | Description | Key/Role |
|--------|-----------|-------------|----------|
| `product_1` | STRING | First product name | Dimension |
| `product_1_id` | INT | First product identifier | Dimension |
| `product_1_department` | STRING | First product department | Dimension |
| `product_2` | STRING | Second product name | Dimension |
| `product_2_id` | INT | Second product identifier | Dimension |
| `product_2_department` | STRING | Second product department | Dimension |
| `orders_with_both` | BIGINT | COUNT(DISTINCT order_key) where both products appear | Metric |
| `customers_buying_both` | BIGINT | COUNT(DISTINCT customer_key) | Metric |
| `pair_frequency_pct` | DECIMAL(31,4) | (orders_with_both / total_orders) × 100 | Metric |

**Filters**: Minimum 100 co-occurrences; Limited to top 1,000 pairs for performance

**Example**: ("Bag of Organic Bananas", "Organic Hass Avocado") appears in 64,761 orders

---

## Data Quality Notes

### Bronze to Silver

* **_rescued_data**: All NULL across all Bronze tables (no malformed CSV records)
* **Type Conversions**: aisle_id and department_id successfully CAST from STRING to INT
* **Dropped Rows**:
  * products: 1 row (NULL in required fields)
  * orders: 75,000 rows (NULL in required fields)
  * order_products: 0 rows

### Silver to Gold

* **Orphan Products**: 3 products in silver_order_products do not exist in silver_products (documented data quality issue)
* **Dropped Rows**: 3 rows from fact_order_items (orphan products filtered)

### Validation Results

* **NULL Checks**: 0 NULLs in required fields (Silver layer)
* **Primary Key Uniqueness**: 0 duplicates in all tables
* **Referential Integrity**: 0 orphans in Gold dimensional model (orphan products removed)
* **Fact Table Grain**: 0 duplicates at (order_key, product_key) level

---

**Last Updated**: September 2, 2026  
**Document Owner**: Tina (Cristina)  
**Project**: Engineer Instacart