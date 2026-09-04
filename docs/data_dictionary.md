# Data Dictionary

**Instacart Pipeline**

This data dictionary provides detailed schema information for all tables across the Bronze, Silver, and Gold layers.

---

## How to Use This Dictionary

**Table Organization**: Bronze → Silver → Gold

**Column Information**:
* **Column Name**: Exact column name as it appears in the table
* **Data Type**: Databricks/Spark SQL data type
* **Nullable**: Whether the column accepts NULL values
* **Description**: Business meaning and technical notes
* **Primary Key (PK)**: Indicates primary key columns
* **Foreign Key (FK)**: Indicates foreign key relationships

---

## BRONZE LAYER

**Catalog/Schema**: `workspace.instacart_bronze`

**Purpose**: Raw ingestion from CSV files with minimal transformation

**Common Columns**: All Bronze tables include `_rescued_data` (STRING, nullable) for malformed CSV records (validated as all NULL)

### bronze_aisles

**Source**: `aisles.csv`  
**Row Count**: 134  
**Grain**: One row per aisle

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| aisle_id | INT | No | ✓ | | Unique aisle identifier |
| aisle | STRING | Yes | | | Aisle name (e.g., "fresh fruits", "packaged cheese") |
| _rescued_data | STRING | Yes | | | Malformed CSV records (all NULL) |

### bronze_departments

**Source**: `departments.csv`  
**Row Count**: 21  
**Grain**: One row per department

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| department_id | INT | No | ✓ | | Unique department identifier |
| department | STRING | Yes | | | Department name (e.g., "produce", "dairy eggs") |
| _rescued_data | STRING | Yes | | | Malformed CSV records (all NULL) |

### bronze_products

**Source**: `products.csv`  
**Row Count**: 49,688  
**Grain**: One row per product

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| product_id | INT | No | ✓ | | Unique product identifier |
| product_name | STRING | Yes | | | Product name |
| aisle_id | INT | Yes | | | Aisle identifier |
| department_id | INT | Yes | | | Department identifier |
| _rescued_data | STRING | Yes | | | Malformed CSV records (all NULL) |

### bronze_orders

**Source**: `orders.csv`  
**Row Count**: 3,421,083  
**Grain**: One row per order

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| order_id | INT | No | ✓ | | Unique order identifier |
| user_id | INT | Yes | | | Customer identifier |
| eval_set | STRING | Yes | | | Dataset split: 'prior' or 'train' |
| order_number | INT | Yes | | | Customer's order sequence (1, 2, 3, ...) |
| order_dow | INT | Yes | | | Day of week (0=Sunday, 6=Saturday) |
| order_hour_of_day | INT | Yes | | | Hour of day (0-23) |
| days_since_prior_order | DOUBLE | Yes | | | Days since last order (NULL for first order) |
| _rescued_data | STRING | Yes | | | Malformed CSV records (all NULL) |

### bronze_order_products_prior

**Source**: `order_products__prior.csv`  
**Row Count**: 32,434,489  
**Grain**: One row per product per order

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| order_id | INT | No | ✓ | | Order identifier |
| product_id | INT | No | ✓ | | Product identifier |
| add_to_cart_order | INT | No | ✓ | | Sequence product was added to cart (1, 2, 3, ...) |
| reordered | INT | Yes | | | Binary: 1 = reorder, 0 = first purchase |
| _rescued_data | STRING | Yes | | | Malformed CSV records (all NULL) |

### bronze_order_products_train

**Source**: `order_products__train.csv`  
**Row Count**: 1,384,617  
**Grain**: One row per product per order

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| order_id | INT | No | ✓ | | Order identifier |
| product_id | INT | No | ✓ | | Product identifier |
| add_to_cart_order | INT | No | ✓ | | Sequence product was added to cart |
| reordered | INT | Yes | | | Binary: 1 = reorder, 0 = first purchase |
| _rescued_data | STRING | Yes | | | Malformed CSV records (all NULL) |

### bronze_validation

**Source**: Validation query across all Bronze tables  
**Row Count**: 6 (one per Bronze table)  
**Grain**: One validation summary row per Bronze table

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| table_name | STRING | No | | | Bronze table being validated |
| expected_rows | INT | No | | | Expected row count from approved snapshot |
| actual_rows | BIGINT | No | | | Actual row count in Bronze table |
| row_difference | BIGINT | No | | | actual_rows - expected_rows (must be 0 for PASS) |
| null_required_ids | BIGINT | No | | | Count of rows with NULL in required ID columns |
| duplicate_primary_keys | BIGINT | No | | | Count of duplicate primary key values |
| duplicate_alternate_keys | BIGINT | No | | | Count of duplicate alternate key values |
| required_field_issues | BIGINT | No | | | Count of NULL or empty required fields |
| domain_issues | BIGINT | No | | | Count of out-of-range or invalid domain values |
| rescued_rows | BIGINT | No | | | Count of rows with non-NULL _rescued_data |
| status | STRING | No | | | 'PASS' if all checks = 0, otherwise 'FAIL' |
| bronze_validation_check | VOID | Yes | | | assert_true result (raises error on any FAIL) |

**Validation Rules**:
* Row counts must exactly match expected snapshot counts
* All required identifiers must be non-NULL
* Primary and alternate keys must be unique
* Required fields must be populated
* Domain values must fall within valid ranges
* No rescued data should remain (all _rescued_data must be NULL)

**Expected Result**: All 6 tables show status = 'PASS'

---

## SILVER LAYER

**Catalog/Schema**: `workspace.instacart_silver`

**Purpose**: Cleaned, standardized, and validated data

**Common Transformations**:
* `_rescued_data` dropped (validated as all NULL)
* NULL filtering on required columns
* Type conversions where needed
* `loaded_at` (TIMESTAMP) added to all tables

### silver_aisles

**Source**: `bronze_aisles`  
**Row Count**: 134 (0 dropped)  
**Grain**: One row per aisle

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| aisle_id | INT | No | ✓ | | Unique aisle identifier |
| aisle | STRING | No | | | Aisle name |
| loaded_at | TIMESTAMP | Yes | | | ETL load timestamp |

### silver_departments

**Source**: `bronze_departments`  
**Row Count**: 21 (0 dropped)  
**Grain**: One row per department

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| department_id | INT | No | ✓ | | Unique department identifier |
| department | STRING | No | | | Department name |
| loaded_at | TIMESTAMP | Yes | | | ETL load timestamp |

### silver_products

**Source**: `bronze_products`  
**Row Count**: 49,687 (1 dropped)  
**Grain**: One row per product

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| product_id | INT | No | ✓ | | Unique product identifier |
| product_name | STRING | No | | | Product name |
| aisle_id | INT | No | | ✓ | FK to silver_aisles.aisle_id (CAST from STRING) |
| department_id | INT | No | | ✓ | FK to silver_departments.department_id (CAST from STRING) |
| loaded_at | TIMESTAMP | Yes | | | ETL load timestamp |

**Transformation Notes**:
* 1 row dropped due to NULL filtering
* Backslash artifacts stripped (120 rows affected)

### silver_orders

**Source**: `bronze_orders`  
**Row Count**: 3,346,083 (75,000 dropped)  
**Grain**: One row per order

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| order_id | INT | No | ✓ | | Unique order identifier |
| user_id | INT | No | | | Customer identifier |
| eval_set | STRING | Yes | | | Dataset split: 'prior' or 'train' |
| order_number | INT | Yes | | | Customer's order sequence |
| order_dow | INT | Yes | | | Day of week (0=Sunday) |
| order_hour_of_day | INT | Yes | | | Hour (0-23) |
| days_since_prior_order | DOUBLE | Yes | | | Days since last order (NULL = first order) |
| loaded_at | TIMESTAMP | Yes | | | ETL load timestamp |

**Transformation Notes**:
* 75,000 rows dropped (NULL `order_id` or `user_id`)
* `days_since_prior_order` NULL preserved (valid for first orders)

### silver_order_products

**Source**: `bronze_order_products_prior` UNION `bronze_order_products_train`  
**Row Count**: 33,819,106 (0 dropped)  
**Grain**: One row per product per order

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| order_id | INT | No | ✓ | ✓ | FK to silver_orders.order_id |
| product_id | INT | No | ✓ | ✓ | FK to silver_products.product_id |
| add_to_cart_order | INT | No | ✓ | | Sequence in cart |
| reordered | INT | Yes | | | Binary: 1 = reorder, 0 = first purchase |
| source_system | STRING | Yes | | | 'prior' or 'train' (tracks origin dataset) |
| loaded_at | TIMESTAMP | Yes | | | ETL load timestamp |

**Transformation Notes**:
* UNION of prior + train datasets
* `source_system` column added to track origin
* 0 rows dropped
* All FK constraints pass validation (0 orphans)

### silver_validation

**Source**: Validation query across all Silver tables  
**Row Count**: 5 (one per Silver table)  
**Grain**: One validation summary row per Silver table

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| table_name | STRING | No | | | Silver table being validated |
| raw_rows | BIGINT | No | | | Row count from source Bronze table(s) |
| clean_rows | BIGINT | No | | | Row count in cleaned Silver table |
| row_difference | BIGINT | No | | | clean_rows - raw_rows (negative = rows dropped intentionally) |
| null_key_rows | BIGINT | No | | | Count of rows with NULL primary key |
| duplicate_keys | BIGINT | No | | | Count of duplicate key values |
| required_field_issues | BIGINT | No | | | Count of NULL/empty required fields + text artifacts (e.g., backslash in product_name) |
| unmatched_fk_rows | BIGINT | No | | | Count of foreign key values not found in parent tables |
| status | STRING | No | | | 'PASS' if all issue counts = 0, otherwise 'REVIEW' |

**Validation Rules**:
* Primary keys must be non-NULL and unique
* Required fields must be populated and clean
* Foreign keys must reference existing parent records
* Text quality issues (e.g., stray backslashes) must be resolved
* `row_difference` is informational only and does not affect status (intentional data quality filtering)

**Expected Result**: All 5 tables show status = 'PASS'

**Key Differences from Bronze Validation**:
* Uses 'PASS'/'REVIEW' instead of 'PASS'/'FAIL'
* Does not enforce exact row counts (drops are expected)
* Includes cross-table referential integrity checks
* Validates text cleaning effectiveness

---

## GOLD LAYER

**Catalog/Schema**: `workspace.instacart_gold`

**Purpose**: Dimensional star schema optimized for analytics

**Unity Catalog Constraints**: Primary Keys (PK) and Foreign Keys (FK) enforced

### dim_product

**Source**: `silver_products` + `silver_aisles` + `silver_departments` (denormalized joins)  
**Row Count**: 49,687  
**Grain**: One row per product  
**Primary Key**: `product_id` (Unity Catalog constraint: `dim_product_pk`)

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| product_id | INT | No | ✓ | | Unique product identifier (PK) |
| product_name | STRING | Yes | | | Product name |
| aisle_id | INT | Yes | | | Aisle identifier (denormalized) |
| aisle_name | STRING | Yes | | | Aisle name (e.g., "fresh fruits") |
| department_id | INT | Yes | | | Department identifier (denormalized) |
| department_name | STRING | Yes | | | Department name (e.g., "produce") |
| product_hierarchy | STRING | Yes | | | Full hierarchy: "department / aisle / product" |
| loaded_at | TIMESTAMP | Yes | | | ETL load timestamp |

**Denormalization**: Aisle and department names joined and embedded for query performance

**Unity Catalog Constraints**:
* Primary Key: `dim_product_pk` on `product_id`

### dim_order

**Source**: `silver_orders` with derived temporal attributes  
**Row Count**: 3,346,083  
**Grain**: One row per order  
**Primary Key**: `order_id` (Unity Catalog constraint: `dim_order_pk`)

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| order_id | INT | No | ✓ | | Unique order identifier (PK) |
| user_id | INT | Yes | | | Customer identifier |
| eval_set | STRING | Yes | | | 'prior' or 'train' |
| order_number | INT | Yes | | | Customer's order sequence |
| order_dow | INT | Yes | | | Day of week (0-6) |
| day_of_week_name | STRING | Yes | | | Derived: 'Sunday', 'Monday', etc. |
| order_hour_of_day | INT | Yes | | | Hour (0-23) |
| time_of_day_bucket | STRING | Yes | | | Derived: 'Early Morning', 'Morning', 'Afternoon', 'Evening', 'Night' |
| days_since_prior_order | DOUBLE | Yes | | | Days since last order (NULL = first) |
| loaded_at | TIMESTAMP | Yes | | | ETL load timestamp |

**Derived Columns**:
* `day_of_week_name`: CASE expression from `order_dow`
* `time_of_day_bucket`: CASE expression from `order_hour_of_day`
  * 0-5: Early Morning
  * 6-11: Morning
  * 12-17: Afternoon
  * 18-21: Evening
  * 22-23: Night

**Unity Catalog Constraints**:
* Primary Key: `dim_order_pk` on `order_id`

### fact_order_product

**Source**: `silver_order_products` + `silver_orders` (for user_id denormalization)  
**Row Count**: 33,819,106 (0 orphan products filtered)  
**Grain**: One row per product per order (order line item)  
**Primary Key**: Composite (`order_id`, `add_to_cart_order`) (Unity Catalog constraint: `fact_order_product_pk`)

| Column | Data Type | Nullable | PK | FK | Description |
|--------|-----------|----------|----|----|-------------|
| order_id | INT | No | ✓ | ✓ | Composite PK component, FK to dim_order.order_id |
| product_id | INT | No | | ✓ | FK to dim_product.product_id |
| add_to_cart_order | INT | No | ✓ | | Composite PK component, cart sequence (measure) |
| reordered | BOOLEAN | Yes | | | Measure: TRUE = reorder, FALSE = first purchase |
| user_id | INT | Yes | | | Denormalized customer identifier (from dim_order) |
| source_system | STRING | Yes | | | 'prior' or 'train' |
| loaded_at | TIMESTAMP | Yes | | | ETL load timestamp |

**Measures**:
* `add_to_cart_order`: Semi-additive (cart position)
* `reordered`: Fully additive (SUM = reorder count, AVG = reorder rate)

**Unity Catalog Constraints**:
* Primary Key: `fact_order_product_pk` on (`order_id`, `add_to_cart_order`)
* Foreign Key: `fact_order_product_product_fk` on `product_id` → `dim_product.product_id`
* Foreign Key: `fact_order_product_order_fk` on `order_id` → `dim_order.order_id`

**Data Quality**:
* All FK constraints pass validation (0 orphans)
* Referential integrity enforced by Unity Catalog

---

## Data Type Reference

### Databricks SQL Data Types

| Data Type | Description | Example Values |
|-----------|-------------|----------------|
| INT | 32-bit signed integer | 1, 42, 1000000 |
| DOUBLE | 64-bit floating point | 7.5, 17.123456 |
| STRING | Variable-length character string | "Banana", "produce" |
| BOOLEAN | True/False logical value | TRUE, FALSE |
| TIMESTAMP | Date and time with microsecond precision | 2026-09-04 10:30:15 |

### Nullable Column Guidelines

**NOT NULL Columns**:
* Primary keys
* Foreign keys in fact tables
* Required business attributes

**NULL-able Columns**:
* Optional descriptive attributes
* Derived/calculated fields
* Metadata columns (e.g., `loaded_at`)
* Fields with valid NULL business meaning (e.g., `days_since_prior_order` for first orders)

---


## Column Naming Conventions

**Primary Keys**: Singular form + `_id` suffix (e.g., `product_id`, `order_id`)

**Foreign Keys**: Match the primary key name in the referenced table

**Measures**: Descriptive names (e.g., `reordered`, `add_to_cart_order`)

**Derived Attributes**: Descriptive, business-friendly names (e.g., `day_of_week_name`, `time_of_day_bucket`, `product_hierarchy`)

**Metadata**: `loaded_at` (timestamp), `source_system` (string)

**Reserved Names**: Avoid SQL keywords, use lowercase with underscores

---

## Data Quality Notes

### Known Issues

**75,000 Orders Dropped**:
* **Location**: `bronze_orders` → `silver_orders`
* **Issue**: NULL `order_id` or `user_id`
* **Impact**: 2.2% of orders excluded from Silver layer
* **Root Cause**: Data quality filter (expected behavior)
* **Status**: Validated, documented

### Data Quality Validation

**Bronze Layer**:
* ✓ Zero malformed CSV records (`_rescued_data` all NULL)
* ✓ All source row counts match

**Silver Layer**:
* ✓ Primary key uniqueness enforced (0 duplicates)
* ✓ Type conversions successful (STRING → INT)
* ✓ Referential integrity validated (3 orphans documented)

**Gold Layer**:
* ✓ Unity Catalog PK/FK constraints successfully applied
* ✓ 0 orphans in fact table
* ✓ All measures validated (reordered is 0/1, add_to_cart_order > 0)

### Resolved Issues

**CSV Parsing (Products)**:
* **Issue**: Embedded quotation marks in product names (e.g., `Bag of Organic Bananas, "Bunch"`) caused parsing errors, creating malformed product records
* **Root Cause**: Default CSV reader settings did not handle embedded quotes correctly
* **Fix**: Added explicit `quote => '"'` and `escape => '"'` settings to Bronze products reader (Cell 04)
* **Impact**: 0 orphan products in Silver and Gold layers
* **Status**: Resolved by Nadine in Bronze notebook

---

**Last Updated**: 2026-09-04  
**Data Dictionary Version**: 1.0 (workspace.instacart_gold implementation)  
**Maintained By**: FTW Data Engineering Batch 12
