# Engineering Decisions

**Instacart Data Engineering Pipeline — Architecture Decision Record**

This document captures key engineering decisions made during the implementation of the Instacart data pipeline, including the rationale, alternatives considered, and consequences of each choice.

---

## Decision Log Format

Each decision is documented with:
* **Decision**: What was decided
* **Context**: Background and constraints
* **Alternatives Considered**: Other options evaluated
* **Rationale**: Why this choice was made
* **Consequences**: Impact and trade-offs
* **Status**: Active, Superseded, or Deprecated
* **Date**: When the decision was made

---

## Decision 1: Medallion Architecture (Bronze → Silver → Gold)

**Decision**: Implement a three-layer Medallion architecture

**Context**:
* Need to process raw CSV files into analytics-ready dimensional model
* Multiple stages of data quality improvement required
* Team members working on different pipeline stages

**Alternatives Considered**:
1. **Single-stage ETL**: Direct load from CSV to dimensional model
2. **Two-layer (Raw → Curated)**: Skip intermediate Silver layer
3. **Four-layer (add Platinum/consumption layer)**: Extra aggregation layer

**Rationale**:
* **Bronze**: Preserves raw data for audit and reprocessing
* **Silver**: Centralizes data quality rules (type conversion, NULL handling, UNION logic)
* **Gold**: Separates dimensional modeling from data cleaning
* Industry-standard pattern with proven benefits
* Clear ownership boundaries for team collaboration

**Consequences**:
* ✅ **Positive**:
  * Clear separation of concerns
  * Easy to debug data quality issues (layer-by-layer validation)
  * Reusable Silver tables for multiple Gold models
  * Bronze layer serves as permanent raw backup
* ⚠️ **Negative**:
  * Additional storage cost (~3x data duplication)
  * More tables to manage and document

**Source**:
* Bronze notebook: Schema creation and table structure
* Silver notebook: Data cleaning and type conversions
* Gold notebook: Dimensional model DDL

**Status**: Active  
**Date**: 2026-09-01

---

## Decision 2: Unity Catalog with PK/FK Constraints

**Decision**: Use Unity Catalog with enforced Primary Key and Foreign Key constraints

**Context**:
* Databricks Unity Catalog supports declarative PK/FK constraints
* Need to enforce referential integrity in dimensional model
* Alternative: Document relationships without enforcement

**Alternatives Considered**:
1. **No constraints**: Document relationships in metadata only
2. **Application-layer validation**: Check integrity in Spark/SQL code
3. **Unity Catalog constraints (chosen)**

**Rationale**:
* **Declarative**: Constraints declared in table DDL, self-documenting
* **Enforcement**: Unity Catalog validates referential integrity at write time
* **Query optimization**: Databricks optimizer can leverage constraints
* **Data quality**: Prevents orphan records in fact table
* **Standards compliance**: Aligns with traditional RDBMS best practices

**Consequences**:
* ✅ **Positive**:
  * Guaranteed referential integrity
  * Self-documenting schema relationships
  * Potential query performance improvements
  * Prevents data quality issues at the source
* ⚠️ **Negative**:
  * Constraints must be added after initial table creation (requires separate ALTER TABLE)
  * 3 orphan products required filtering before FK constraint application
  * Cannot load data violating constraints (strict enforcement)

**Source**:
* Gold notebook: Cell with ALTER TABLE ADD CONSTRAINT statements for PK and FK
* Gold notebook: Constraint validation query (Query 18 - pre-constraint checks)
* Decision implementation: Lines applying CONSTRAINT to dim_order, dim_product, fact_order_products

**Status**: Active  
**Date**: 2026-09-03

---

## Decision 3: Separate Gold Schema (workspace.instacart_gold)

**Decision**: Create dedicated `workspace.instacart_gold` schema for dimensional model

**Context**:
* Bronze and Silver layers already in `workspace.default`
* Need to separate production-ready Gold tables from intermediate layers
* Alternative: Keep all layers in single schema

**Alternatives Considered**:
1. **Single schema (workspace.default)**: All layers in one schema
2. **Separate schemas per layer**: bronze_schema, silver_schema, gold_schema
3. **Gold-only separate schema (chosen)**

**Rationale**:
* **Clarity**: Clear distinction between intermediate (Bronze/Silver) and production (Gold) tables
* or analysts
* **Naming Consistency**: Gold tables follow clean naming convention (dim_, fact_) without conflicting with legacy tables
* **Migration Path**: Enables phased migration from old (workspace.default) to new (workspace.instacart_gold)

**Consequences**:
* ✅ **Positive**:
  * Clear separation of production-ready tables
  * Simplified access control management
  * Clean naming without legacy conflicts
  * Easy to identify Gold tables in queries
* ⚠️ **Negative**:
  * Cross-schema queries required when joining Bronze/Silver with Gold
  * Additional schema management overhead

**Source**:
* Gold notebook: CREATE SCHEMA workspace.instacart_gold statement
* Gold notebook: All CREATE TABLE statements with fully qualified names (workspace.instacart_gold.dim_*, workspace.instacart_gold.fact_*)

**Status**: Active  
**Date**: 2026-09-03

---

## Decision 4: No Separate Customer Dimension

**Decision**: Embed customer attributes in `dim_order` instead of creating `dim_customer`

**Context**:
* Traditional star schema often includes separate customer dimension
* Instacart data has customer attributes (user_id, order_number, frequency)
* Orders are the primary analysis grain

**Alternatives Considered**:
1. **Separate dim_customer**: Traditional approach with order FK to customer
2. **Embed in dim_order (chosen)**: Customer attributes in order dimension
3. **Embed in fact table**: Denormalize all customer attributes into fact

**Rationale**:
* **Query Simplicity**: Most queries analyze orders, not customers directly
* **Fewer Joins**: Avoid multi-hop joins (fact → order → customer)
* **Order-Centric Analysis**: Orders are the primary grain, customers derive from aggregation
* **Simplicity**: Simplified star schema (2 dimensions + 1 fact)
* **Performance**: Faster query execution (one less join)

**Consequences**:
* ✅ **Positive**:
  * Simpler queries (fact → order, fact → product)
  * Faster query performance (fewer joins)
  * Easier dashboard design (no customer dimension to manage)
  * Customer metrics easily derived via aggregation (MAX(order_number), AVG(days_since_prior_order))
* ⚠️ **Negative**:
  * user_id repeated across all orders (storage overhead)
  * Cannot track customer attribute changes over time (no SCD Type 2)
  * Customer-centric queries require aggregation from dim_order

**Future Consideration**: Phase 2 may split into separate `dim_customer` if:
* Customer-centric analysis becomes primary use case
* Need to track customer segmentation changes (SCD Type 2)
* Storage cost of repeated user_id becomes significant

**Source**:
* Gold notebook: CREATE TABLE dim_order with user_id, order_number, days_since_prior_order columns
* Gold notebook: No CREATE TABLE dim_customer statement (intentionally omitted)
* Data model documentation: dim_order schema includes customer attributes

**Status**: Active (under review for Phase 2)  
**Date**: 2026-09-03

---

## Decision 5: Composite Primary Key in Fact Table

**Decision**: Use composite PK (`order_id`, `add_to_cart_order`) instead of surrogate key

**Context**:
* Need unique identifier for each order line item
* `add_to_cart_order` serves dual purpose: PK component and measure
* Alternative: Generate surrogate key (row_number, GUID)

**Alternatives Considered**:
1. **Composite natural key (chosen)**: (`order_id`, `add_to_cart_order`)
2. **Surrogate key (auto-increment)**: Generate sequential order_item_id
3. **GUID/UUID**: Generate random unique identifier

**Rationale**:
* **Semantic Meaning**: Composite key preserves business meaning
* **No Generation Overhead**: No need to generate surrogate key
* **Dual Purpose**: `add_to_cart_order` is both PK component and measure
* **Natural Uniqueness**: These two columns naturally identify each line item

**Consequences**:
* ✅ **Positive**:
  * Preserves semantic meaning in primary key
  * No surrogate key generation overhead
  * `add_to_cart_order` serves dual purpose (PK + measure)
  * Easier to debug (meaningful key values)
* ⚠️ **Negative**:
  * Composite key requires two columns (vs. single surrogate)
  * FK references must include both columns (not applicable here)
  * Slightly more complex Unity Catalog constraint syntax

**Source**:
* Gold notebook: CREATE TABLE fact_order_products with PRIMARY KEY (order_id, add_to_cart_order)
* Gold notebook: ALTER TABLE ADD CONSTRAINT for composite PK
* No surrogate key generation logic (intentionally absent)

**Status**: Active  
**Date**: 2026-09-03

---

## Decision 6: Denormalized Product Hierarchy

**Decision**: Embed aisle_name and department_name in `dim_product` (denormalized star schema)

**Context**:
* Product hierarchy: department → aisle → product
* Traditional approach: Snowflake schema with separate aisle/department tables
* Query performance vs. normalization trade-off

**Alternatives Considered**:

1. **Denormalized star (chosen)**: Embed hierarchy in dim_product
2. **Hybrid**: Keep separate tables but also embed names

**Rationale**:
* **Query Performance**: Avoid additional joins for common queries
* **Star Schema Best Practice**: Kimball methodology recommends denormalization
* **Read-Heavy Workload**: Analytics workload benefits from fewer joins
* **Dimension Stability**: Aisle/department names rarely change (no update anomaly risk)
* **Dashboard Simplicity**: Easier filter design (single table)

**Consequences**:
* ✅ **Positive**:
  * Faster queries (no joins to aisle/department tables)
  * Simpler query syntax
  * Better dashboard performance
  * Single table for all product attributes
* ⚠️ **Negative**:
  * Aisle/department names repeated across products (storage cost)
  * If aisle/department names change, must update multiple rows
  * Slightly larger dimension table (minimal impact)

**Source**:
* Gold notebook: CREATE TABLE dim_product with aisle_name, department_name columns (denormalized)
* Gold notebook: JOIN to silver_aisles and silver_departments during dim_product population
* No separate dim_aisle or dim_department tables created

**Status**: Active  
**Date**: 2026-09-03

---

## Decision 7: Derived Temporal Attributes

**Decision**: Pre-compute `day_of_week_name` and `time_of_day_bucket` in `dim_order`

**Context**:
* Orders have temporal attributes (order_dow, order_hour_of_day)
* Analysts prefer human-readable names over numeric codes
* Alternative: Compute in query CASE statements

**Alternatives Considered**:
1. **Query-time derivation**: CASE statements in every query
2. **Pre-computed columns (chosen)**: Derive during ETL
3. **Lookup tables**: Separate time dimension tables

**Rationale**:
* **Query Performance**: Avoid CASE expressions in every query
* **Consistency**: Single source of truth for time bucket definitions
* **Business-Friendly**: Readable column names in result sets
* **Dashboard Simplicity**: Direct column references, no CASE logic

**Consequences**:
* ✅ **Positive**:
  * Faster query performance (no CASE expressions)
  * Consistent bucketing logic across all queries
  * Simplified query syntax
  * Business-friendly result sets
* ⚠️ **Negative**:
  * Additional storage for derived columns (minimal cost)
  * Time bucket definitions locked in ETL (cannot change without rebuild)

**Time Bucket Definitions**:
* Early Morning: 0-5
* Morning: 6-11
* Afternoon: 12-17
* Evening: 18-21
* Night: 22-23

**Source**:
* Gold notebook: CREATE TABLE dim_order with day_of_week_name and time_of_day_bucket columns
* Gold notebook: CASE expression for order_dow → day_of_week_name mapping (0='Sunday', 1='Monday', ...)
* Gold notebook: CASE expression for order_hour_of_day → time_of_day_bucket (WHEN order_hour_of_day BETWEEN 0 AND 5 THEN 'Early Morning', ...)

**Status**: Active  
**Date**: 2026-09-03

---

## Decision 8: UNION Prior + Train Datasets

**Decision**: UNION `order_products__prior.csv` and `order_products__train.csv` in Silver layer

**Context**:
* Source data split into two files (prior and train)
* Both represent the same business entity (order line items)
* Need single unified table for dimensional modeling

**Alternatives Considered**:
1. **Keep separate**: Maintain bronze_order_products_prior and _train through Gold
2. **UNION in Silver (chosen)**: Combine in silver_order_products
3. **UNION in Gold**: Combine during fact table creation

**Rationale**:
* **Single Source of Truth**: One Silver table for all order products
* **Simplified Downstream**: Gold layer doesn't need to handle multiple sources
* **Lineage Tracking**: `source_system` column preserves origin
* **Early Consolidation**: Data quality issues addressed once

**Consequences**:
* ✅ **Positive**:
  * Single table for all order line items
  * Simplified Gold layer logic
  * `source_system` column enables filtering by origin if needed
  * Consistent row count tracking
* ⚠️ **Negative**:
  * Cannot easily separate prior/train after Silver (must filter by source_system)
  * If prior/train have different quality issues, harder to isolate

**Source**:
* Silver notebook (Ina): CREATE TABLE silver_order_products with UNION ALL
* Silver notebook: SELECT * FROM bronze_order_products_prior ... UNION ALL ... SELECT * FROM bronze_order_products_train
* Silver notebook: source_system column ('prior' or 'train') to track origin

**Status**: Active  
**Date**: 2026-09-02

---

## Decision 9: Handle 3 Orphan Products via Filtering (will verify)

**Decision**: Filter 3 orphan products (product_id not in silver_products) when creating Gold fact table

**Context**:
* Discovered 3 product_ids in `silver_order_products` that don't exist in `silver_products`
* Prevent FK constraint violation
* Alternative: Investigate and fix upstream source data

**Alternatives Considered**:
1. **Filter orphans (chosen)**: Exclude from Gold layer
2. **Create placeholder products**: Insert dummy records in dim_product
3. **Fail pipeline**: Block until source data fixed

**Rationale**:
* **Pragmatic**: Unblock pipeline while documenting issue
* **Small Impact**: Only 3 rows out of 33.8M (0.000009%)
* **FK Compliance**: Allows Unity Catalog FK constraint to be applied
* **Documented**: Issue tracked in validation.md and data_dictionary.md

**Consequences**:
* ✅ **Positive**:
  * Pipeline completes successfully
  * Unity Catalog FK constraints enforced
  * Issue documented for future investigation
  * Minimal data loss (3 rows)
* ⚠️ **Negative**:
  * 3 transactions excluded from analysis
  * Root cause not fixed (upstream source data issue)
  * Must remember to filter in future pipeline runs

**Source**:
* Silver notebook (Ina): Validation query identifying 3 orphan products (product_id in order_products but not in products)
* Gold notebook (Cath): CREATE TABLE fact_order_products with WHERE clause filtering orphans
* Gold notebook: WHERE product_id IN (SELECT product_id FROM dim_product) to enforce FK
* Data dictionary: Documented in silver_order_products quality issues

**Status**: Active (documented as known issue)  
**Date**: 2026-09-03

---


## Decision 10: Preserve days_since_prior_order NULL Values

**Decision**: Keep `days_since_prior_order` as NULL for first customer orders instead of replacing with 0 or -1

**Context**:
* NULL represents "first order, no prior order exists"
* Alternative: Replace NULL with default value (0, -1, 999)

**Alternatives Considered**:
1. **Preserve NULL (chosen)**: NULL = first order
2. **Replace with 0**: Could be misinterpreted as "ordered yesterday"
3. **Replace with -1**: Sentinel value indicating first order

**Rationale**:
* **Semantic Accuracy**: NULL correctly represents "not applicable"
* **Avoid Misinterpretation**: 0 would suggest previous order yesterday
* **Standard SQL Practice**: NULL for missing/not applicable
* **Query Flexibility**: Can filter first orders with `WHERE days_since_prior_order IS NULL`

**Consequences**:
* ✅ **Positive**:
  * Semantically correct representation
  * Easy to identify first orders (`IS NULL`)
  * No risk of misinterpreting 0 or -1
  * Aligns with SQL best practices
* ⚠️ **Negative**:
  * Must handle NULLs in aggregations (AVG ignores NULLs by default, which is correct)
  * Queries filtering by this column must consider NULL case

**Source**:
* Bronze notebook (Nadine): days_since_prior_order loaded as-is from orders.csv (preserving NULL)
* Silver notebook (Ina): days_since_prior_order passed through without transformation
* Gold notebook (Cath): dim_order.days_since_prior_order preserved as nullable column
* No COALESCE or IFNULL transformation applied at any layer

**Status**: Active  
**Date**: 2026-09-02

---

## Decision 11: Convert reordered from INT to BOOLEAN in Gold

**Decision**: Change `reordered` from INT (0/1) to BOOLEAN (TRUE/FALSE) in fact table

**Context**:
* Source data uses INT (0 = first purchase, 1 = reorder)
* Databricks supports BOOLEAN type
* Alternative: Keep as INT

**Alternatives Considered**:
1. **Keep INT**: Preserve source data type
2. **Convert to BOOLEAN (chosen)**: Use semantic type

**Rationale**:
* **Semantic Clarity**: BOOLEAN clearly indicates binary flag
* **Type Safety**: Prevents invalid values (2, 3, -1)
* **SQL Clarity**: `WHERE reordered` instead of `WHERE reordered = 1`
* **Industry Standard**: Boolean flags are best practice

**Consequences**:
* ✅ **Positive**:
  * Clearer semantic meaning
  * Type safety (only TRUE/FALSE)
  * Cleaner query syntax
  * Better documentation
* ⚠️ **Negative**:
  * Must CAST to INT for aggregations: `SUM(CAST(reordered AS INT))`
  * Slight syntax overhead in aggregate queries

**Source**:
* Bronze notebook (Nadine): reordered loaded as INT from order_products__prior.csv and order_products__train.csv
* Silver notebook (Ina): reordered preserved as INT
* Gold notebook (Cath): CREATE TABLE fact_order_products with reordered BOOLEAN
* Gold notebook: CAST(reordered AS BOOLEAN) in INSERT statement

**Status**: Active  
**Date**: 2026-09-03

---

## Summary of Active Decisions

| # | Decision | Layer | Status | Impact |
|---|----------|-------|--------|--------|
| 1 | Medallion Architecture | All | Active | ✅ High |
| 2 | Unity Catalog Constraints | Gold | Active | ✅ High |
| 3 | Separate Gold Schema | Gold | Active | ✅ Medium |
| 4 | No Separate Customer Dimension | Gold | Active (review) | ⚠️ Medium |
| 5 | Composite PK in Fact | Gold | Active | ✅ Medium |
| 6 | Denormalized Product Hierarchy | Gold | Active | ✅ High |
| 7 | Derived Temporal Attributes | Gold | Active | ✅ High |
| 8 | UNION Prior + Train | Silver | Active | ✅ High |
| 9 | Filter Orphan Products | Gold | Active (issue) | ⚠️ Low |
| 10 | Preserve NULL Values | Silver/Gold | Active | ✅ Low |
| 11 | BOOLEAN for reordered | Gold | Active | ✅ Low |

---

## Decision 12: Bronze as Typed Source Copy (No Transformation)

**Decision**: Bronze layer performs 1:1 CSV ingestion with explicit schemas, no data cleaning or transformation

**Context**:
* Need to preserve raw source data for audit and lineage
* Type inference can assign incorrect data types
* Alternative: Apply cleaning rules during ingestion

**Alternatives Considered**:
1. **Auto-inferred schemas**: Let Spark guess column types
2. **Typed source copy (chosen)**: Declare explicit schemas, no cleaning
3. **Clean during ingestion**: Apply TRIM, REPLACE, etc. in Bronze

**Rationale**:
* **Audit Trail**: Raw data preserved exactly as received
* **Type Safety**: Explicit schemas prevent inference errors
* **Separation of Concerns**: Bronze = ingestion, Silver = cleaning
* **Reprocessing**: Can re-clean data without re-ingesting
* **Detectability**: `_rescued_data` column captures parsing issues

**Consequences**:
* ✅ **Positive**:
  * Source data preserved for audit
  * No risk of cleaning errors destroying original data
  * Clear layer boundaries (Bronze ≠ Silver)
  * Easy to reprocess with different cleaning rules
* ⚠️ **Negative**:
  * Bronze tables contain raw quality issues (nulls, bad values, duplicates)
  * Cannot query Bronze directly for analytics (must go through Silver)
  * Validation detects issues but doesn't fix them

**Source**:
* Bronze notebook (Nadine): CREATE SCHEMA workspace.instacart_bronze
* Bronze notebook: Six CREATE TABLE statements with explicit schemas (aisles, departments, products, orders, order_products_prior, order_products_train)
* Bronze notebook: read_files() calls with format='csv', header=True, explicit column types
* Bronze notebook: No TRIM, REPLACE, COALESCE, or other transformations in SELECT
* Bronze notebook: _rescued_data column included in all tables to capture parsing failures
* Bronze notebook: bronze_validation cell - consolidated validation query checking row counts and _rescued_data IS NULL

**Implementation Note** (Nadine):
* Bronze validation uses `assert_true` to stop pipeline on failure
* Rescued data column must be NULL (no parser errors)
* Expected row counts hardcoded for this dataset snapshot

**Status**: Active  
**Date**: 2026-09-02  
**Owner**: Nadine

---

## Decision 13: One Bronze Table Per CSV File

**Decision**: Create one Bronze table for each source CSV file (6 tables total)

**Context**:
* Six source CSV files from Instacart dataset
* Need to trace data lineage back to source files
* Alternative: Combine related CSVs during ingestion

**Alternatives Considered**:
1. **One table per CSV (chosen)**: Direct 1:1 mapping
2. **Combine prior + train**: Merge order_products CSVs in Bronze
3. **Normalize during ingestion**: Split/join tables in Bronze

**Rationale**:
* **Lineage**: Easy to trace any row back to its source CSV
* **Simplicity**: No join logic needed in Bronze layer
* **Source Fidelity**: Preserves the structure of received data
* **Debugging**: Can isolate issues to specific source files

**Consequences**:
* ✅ **Positive**:
  * Clear lineage (table name → CSV filename)
  * No complex Bronze logic
  * Easy to reload individual files
  * Validation checks per-file quality
* ⚠️ **Negative**:
  * Two order_products tables in Bronze (prior + train)
  * Must combine them downstream (done in Silver)
  * Slight storage overhead (separate tables)

**Bronze Tables**:
| Table | Source CSV | Grain | Rows |
|---|---|---|---:|
| `aisles` | aisles.csv | One aisle | 134 |
| `departments` | departments.csv | One department | 21 |
| `products` | products.csv | One product | 49,688 |
| `orders` | orders.csv | One order | 3,421,083 |
| `order_products_prior` | order_products__prior.csv | One product line (prior orders) | 32,434,489 |
| `order_products_train` | order_products__train.csv | One product line (train orders) | 1,384,617 |

**Source**:
* Bronze notebook (Nadine): Six separate CREATE TABLE statements (bronze_aisles, bronze_departments, bronze_products, bronze_orders, bronze_order_products_prior, bronze_order_products_train)
* Bronze notebook: Six separate read_files() calls to /Volumes/.../aisles.csv, departments.csv, products.csv, orders.csv, order_products__prior.csv, order_products__train.csv
* Bronze notebook: bronze_validation cell checking row counts for all 6 tables individually

**Status**: Active  
**Date**: 2026-09-02  
**Owner**: Nadine

---

## Decision 14: Fix Products CSV Quote/Escape Handling

**Decision**: Configure CSV reader with explicit quote and escape characters for Products file

**Context**:
* Products CSV has quoted product names with embedded quotes
* Default CSV parser misinterpreted quotes, causing null aisle/department IDs
* Example: `"Product Name ""Brand"" Description"` parsed incorrectly

**Alternatives Considered**:
1. **Fix in Silver**: Clean up parsing errors after ingestion
2. **Fix CSV reader options (chosen)**: Configure quote/escape during ingestion
3. **Pre-process CSV**: Manually edit source file

**Rationale**:
* **Root Cause Fix**: Addresses parsing issue at ingestion, not cleanup
* **No Manual Edits**: Avoids modifying source files
* **Correct Type Assignment**: Aisle/department IDs parsed as INT, not NULL
* **Reusable Pattern**: Same quote/escape config works for any reload

**Implementation**:
```python
read_files(
    path="/Volumes/.../products.csv",
    format="csv",
    header=True,
    quote='"',     # Double quote as quote character
    escape='"'     # Double quote as escape character
)
```

**Consequences**:
* ✅ **Positive**:
  * Products parse correctly on first ingestion
  * No null aisle/department IDs
  * No Silver cleanup needed for this issue
  * Documented pattern for similar CSV issues
* ⚠️ **Negative**:
  * Must remember to apply this config on every Products reload
  * Other CSVs don't need this (file-specific handling)

**Source**:
* Bronze notebook (Nadine): CREATE TABLE bronze_products cell
* Bronze notebook: read_files() call for products.csv with quote='"', escape='"' parameters
* Bronze notebook: Comment explaining quote/escape configuration for embedded quotes in product names
* Data dictionary: Documented in bronze_products description

**Status**: Active  
**Date**: 2026-09-02  
**Owner**: Nadine

---

## Decision 15: Fix Backslash Escaping Bug in Silver

**Decision**: Remove stray backslash characters from `product_name` in Silver layer

**Context**:
* 120 products had `\` character in name (e.g., `Product\"Name`)
* Caused by incorrect CSV escaping in source file (`\""` instead of `"`)
* Backslash is not part of product name, artifact of bad escaping

**Alternatives Considered**:
1. **Keep backslashes**: Leave data as-is
2. **Remove in Silver (chosen)**: `REPLACE(product_name, CHR(92), '')`
3. **Fix in Bronze**: Handle during ingestion

**Rationale**:
* **Data Quality**: Backslash is escaping artifact, not real data
* **Silver Responsibility**: Cleaning happens in Silver, not Bronze
* **Minimal Impact**: Only 120 rows affected
* **User Experience**: Clean product names for analysts

**Implementation** (Ina):
```sql
CREATE OR REPLACE TABLE silver_products AS
SELECT
    product_id,
    REPLACE(product_name, CHR(92), '') AS product_name,  -- Remove backslash
    ...
FROM bronze_products;
```

**Consequences**:
* ✅ **Positive**:
  * Clean product names in Silver/Gold
  * No backslash artifacts in analytics
  * Documented quality fix
* ⚠️ **Negative**:
  * Bronze still contains backslashes (by design)
  * Must apply fix in every Silver refresh

**Source**:
* Silver notebook (Ina): CREATE TABLE silver_products cell
* Silver notebook: REPLACE(product_name, CHR(92), '') AS product_name in SELECT statement
* Silver notebook: Validation query detecting backslash characters (using INSTR)
* Data dictionary: Documented in silver_products quality fixes

**Status**: Active  
**Date**: 2026-09-03  
**Owner**: Ina

---

## Decision 16: Silver Row Count Differences Are Expected

**Decision**: Silver validation does NOT fail on row count differences from Bronze

**Context**:
* Silver layer intentionally filters invalid rows (orphan FKs, out-of-range values)
* Validation checks keys/relationships, not row counts
* Alternative: Require row count parity like Bronze-to-Raw

**Alternatives Considered**:
1. **Strict row count parity**: Fail if Silver ≠ Bronze
2. **Expected differences (chosen)**: Allow row drops, validate keys only
3. **Document drops**: Report dropped rows but don't fail

**Rationale**:
* **Intentional Filtering**: Silver removes bad data (orphan products, invalid ranges)
* **Quality Over Quantity**: Better to drop bad rows than propagate errors
* **Validation Focus**: Check remaining data for nulls/duplicates/FK issues
* **Documentation**: Dropped rows documented in validation.md

**What Silver Validation Checks**:
* ✅ Primary key uniqueness (no duplicates)
* ✅ Required fields not null
* ✅ Foreign key relationships (no orphans in remaining data)
* ✅ Valid value ranges
* ❌ Row count equality (intentionally skipped)

**Consequences**:
* ✅ **Positive**:
  * Can filter bad data without breaking validation
  * Focuses on quality of remaining data
  * Clearly documents expected vs actual row counts
* ⚠️ **Negative**:
  * Row count drop could hide bugs if not documented
  * Must manually track expected drops (e.g., 3 orphan products)

**Source**:
* Silver notebook (Ina): silver_validation cell - consolidated validation query
* Silver notebook: Validation checks for PK uniqueness, NOT NULL, FK existence (NOT row count parity)
* Silver notebook: WHERE clauses filtering invalid data (e.g., orphan products, out-of-range values)
* Data dictionary: silver_validation query definition documenting quality checks (not row count checks)

**Status**: Active  
**Date**: 2026-09-03  
**Owner**: Ina

---

## Decision 17: Silver-to-Silver Depension**: Some Silver tables depend on other Silver tables (not just Bronze)

**Context**:
* `silver_products` validates against `silver_aisles` and `silver_departments` (not Bronze versions)
* `silver_order_products` validates against `silver_orders` (not Bronze version)
* Requires explicit DAG dependencies in Databricks Job

**Alternatives Considered**:
1. **Validate against Bronze**: Check FKs against bronze_aisles, bronze_departments
2. **Validate against Silver (chosen)**: Check FKs against cleaned Silver tables
3. **No validation**: Skip FK checks entirely

**Rationale**:
* **Validation Accuracy**: FK checks should use cleaned data (Silver), not raw (Bronze)
* **Consistency**: Validate against same layer you'll join in Gold
* **Race Condition Prevention**: Explicit dependencies prevent parallel execution bugs
* **Referential Integrity**: Ensures all FKs resolve to existing cleaned records

**Silver Dependencies**:
```
silver_aisles ----┐
                  ├──> silver_products
silver_departments ┘

silver_orders -----> silver_order_products
```

**Implementation Note** (Ina):
* Use `EXISTS` subqueries against Silver tables, not Bronze
* Databricks Job must define task dependencies:
  * Task `silver_products` depends on `silver_aisles` + `silver_departments`
  * Task `silver_order_products` depends on `silver_orders`
* Without dependencies, tables may run in parallel → FK check fails

**Consequences**:
* ✅ **Positive**:
  * Accurate FK validation (against cleaned data)
  * No race conditions
  * Clear DAG structure
* ⚠️ **Negative**:
  * Cannot parallelize all Silver tasks
  * Must maintain explicit Job dependencies
  * Longer total Silver execution time (sequential not parallel)

**Source**:
* Silver notebook (Ina): CREATE TABLE silver_products with FK checks against silver_aisles and silver_departments
* Silver notebook: CREATE TABLE silver_order_products with FK checks against silver_orders
* Silver notebook: WHERE EXISTS (SELECT 1 FROM silver_aisles WHERE ...) and WHERE EXISTS (SELECT 1 FROM silver_departments WHERE ...)
* Silver notebook: WHERE EXISTS (SELECT 1 FROM silver_orders WHERE ...)
* Databricks Job configuration: Task dependencies defining silver_products depends_on [silver_aisles, silver_departments], silver_order_products depends_on [silver_orders]

**Status**: Active  
**Date**: 2026-09-03  
**Owner**: Ina

---

## Decision 18: Use INSTR() for Backslash Detection (Not LIKE)

**Decision**: Use `INSTR(column, CHR(92)) > 0` to detect backslashes, not `LIKE`

**Context**:
* Initial validation used `LIKE CONCAT('%', CHR(92), '%')` to find backslashes
* Spark treats backslash as escape character in LIKE patterns
* Result: False positives (matched `%` symbols instead of backslashes)

**Alternatives Considered**:
1. **LIKE pattern**: `column LIKE CONCAT('%', CHR(92), '%')`
2. **INSTR() function (chosen)**: `INSTR(column, CHR(92)) > 0`
3. **REGEXP**: `column RLIKE '\\\\\\\\`

**Rationale**:
* **Correctness**: INSTR() treats backslash literally, not as escape
* **Simplicity**: No escape character confusion
* **Performance**: INSTR() is faster than REGEXP
* **Readability**: `INSTR(col, CHR(92))` clearer than escaped REGEXP

**Why LIKE Fails**:
```sql
-- WRONG: Backslash escapes the next %, matches any character
WHERE product_name LIKE CONCAT('%', CHR(92), '%')
-- Matches: "Product % Name" (because \ escapes %)

-- CORRECT: INSTR treats backslash literally
WHERE INSTR(product_name, CHR(92)) > 0
-- Matches: "Product\Name" (actual backslash)
```

**Consequences**:
* ✅ **Positive**:
  * Correctly detects backslashes
  * No false positives
  * Simpler syntax than escaped REGEXP
* ⚠️ **Negative**:
  * Must remember this pattern (LIKE seems intuitive but wrong)
  * INSTR() position-based (returns 0 if not found, position if found)

**Recommendation** (Ina):
* Check other validation scripts for similar LIKE patterns with special characters
* Use INSTR() or REGEXP for literal character matching, not LIKE

**Source**:
* Silver notebook (Ina): Backslash detection query using INSTR(product_name, CHR(92)) > 0
* Silver notebook: Earlier version (incorrect) used LIKE CONCAT('%', CHR(92), '%') - now corrected
* Silver notebook: Comment explaining why INSTR is preferred over LIKE for backslash detection

**Status**: Active  
**Date**: 2026-09-03  
**Owner**: Ina

---

## Decision 19: Comprehensive Multi-Stage Constraint Validation

**Decision**: Validate PK/FK constraints in three stages: pre-build, declarative, and final reconciliation

**Context**:
* Unity Catalog enforces PK/FK constraints, but violations block table creation
* Need to validate data quality before attempting constraint creation
* Alternative: Apply constraints blindly and debug failures

**Alternatives Considered**:
1. **No validation**: Apply constraints, fail if data is bad
2. **Pre-validation only**: Check before constraints, skip post-validation
3. **Three-stage validation (chosen)**: Pre-build + declarative + final

**Rationale**:
* **Pre-Build Validation** (Query 18): Detect issues before constraint creation
* **Declarative Constraints**: Unity Catalog ALTER TABLE ADD CONSTRAINT
* **Final Validation** (Query 20): Verify Silver-to-Gold reconciliation + measures
* **Comprehensive Coverage**: Keys, relationships, row counts, aggregates

**Three-Stage Validation** (Cath):

**Stage 1 - Pre-Constraints Validation:**
* Dimension key uniqueness (no duplicate PKs)
* Primary key null checks (must be 0)
* Required field completeness
* **Goal**: Ensure data is constraint-ready before ALTER TABLE

**Stage 2 - Declarative Constraints:**
* Unity Catalog PK constraints on dimensions
* Unity Catalog composite PK on fact table
* Unity Catalog FK constraints (fact → dimensions)
* **Goal**: Enforce at database level

**Stage 3 - Final Validation:**
* Part 1 - Table-level:
  * Silver vs Gold row reconciliation
  * Referential integrity (fact → dimension matches)
  * Key uniqueness confirmed
* Part 2 - Measure reconciliation:
  * Total order lines (Silver = Gold)
  * Distinct orders preserved
  * Reordered count accuracy
  * Cart position sum accuracy
* **Goal**: Verify end-to-end data quality

**Consequences**:
* ✅ **Positive**:
  * Catches issues before constraint creation (saves debugging time)
  * Confirms constraints are actually enforced
  * Validates aggregate measures match source
  * Comprehensive quality coverage
* ⚠️ **Negative**:
  * Three separate validation queries to maintain
  * Longer pipeline execution time
  * Must run all three stages for full confidence

**Source**:
* Gold notebook (Cath): Query 18 cell - pre-constraint validation (PK uniqueness, null checks, required fields)
* Gold notebook: ALTER TABLE ADD CONSTRAINT cells for PK and FK constraints on dim_order, dim_product, fact_order_products
* Gold notebook: Query 20 cell - final validation (Silver-to-Gold reconciliation, measure accuracy, referential integrity)
* Gold notebook: Three separate validation result outputs showing progression through validation stages

**Status**: Active  
**Date**: 2026-09-03  
**Owner**: Cath

---

## Summary of Active Decisions (Updated)

| # | Decision | Layer | Status | Impact |
|---|----------|-------|--------|--------|
| 1 | Medallion Architecture | All | Active | ✅ High |
| 2 | Unity Catalog Constraints | Gold | Active | ✅ High |
| 3 | Separate Gold Schema | Gold | Active | ✅ Medium |
| 4 | No Separate Customer Dimension | Gold | Active (review) | ⚠️ Medium |
| 5 | Composite PK in Fact | Gold | Active | ✅ Medium |
| 6 | Denormalized Product Hierarchy | Gold | Active | ✅ High |
| 7 | Derived Temporal Attributes | Gold | Active | ✅ High |
| 8 | UNION Prior + Train | Silver | Active | ✅ High |
| 9 | Filter Orphan Products | Gold | Active (issue) | ⚠️ Low |
| 10 | Preserve NULL Values | Silver/Gold | Active | ✅ Low |
| 11 | BOOLEAN for reordered | Gold | Active | ✅ Low |
| 12 | Bronze as Typed Source Copy | Bronze | Active | ✅ High |
| 13 | One Table Per CSV | Bronze | Active | ✅ High |
| 14 | Fix Products Quote/Escape | Bronze | Active | ✅ Medium |
| 15 | Fix Backslash in Silver | Silver | Active | ✅ Low |
| 16 | Silver Row Differences Expected | Silver | Active | ✅ Medium |
| 17 | Silver-to-Silver Dependencies | Silver | Active | ✅ High |
| 18 | Use INSTR() for Backslash | Silver | Active | ✅ Low |
| 19 | Multi-Stage Constraint Validation | Gold | Active | ✅ High |

---

## Team Contributions

**Engineering Decisions documented by:**
* **Nadine**: Bronze layer design (Decisions 13-15)
* **Ina**: Silver layer engineering (Decisions 16-19)
* **Cath**: Gold layer validation (Decision 20)
* **Original decisions (1-12)**: Collaborative team design discussions

---

**Last Updated**: 2026-09-04  
**Decision Log Version**: 2.0  
**Maintained By**: FTW Data Engineering Batch 12
