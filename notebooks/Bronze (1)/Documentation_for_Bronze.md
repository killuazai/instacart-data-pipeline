# Instacart Bronze Pipeline Documentation

**Owner:** Nadine  
**Notebook:** `Bronze.ipynb`  
**Platform:** Databricks SQL with Unity Catalog and Delta Lake  
**Catalog:** `workspace`

## 1. Purpose

This notebook builds and validates the Bronze layer of the Instacart data pipeline. It reads six source CSV files from a Unity Catalog volume, applies explicit data types, stores the records as Delta tables, and checks that the ingestion completed without missing rows, invalid required values, duplicate candidate keys, or parsing problems.

The Bronze layer is a typed copy of the source data. It does not clean, filter, deduplicate, enrich, or join the records. Those responsibilities belong to the Silver layer.

## 2. Source location

All source files are expected under:

```text
/Volumes/workspace/default/ftw_b12_de/shared/week06/instacart_csv/
```

The approved source files are:

1. `aisles.csv`
2. `departments.csv`
3. `products.csv`
4. `orders.csv`
5. `order_products__prior.csv`
6. `order_products__train.csv`

## 3. Bronze outputs

The notebook creates the following Delta tables in `workspace.instacart_bronze`:

| Table | Grain | Expected rows |
|---|---|---:|
| `aisles` | One row per aisle | 134 |
| `departments` | One row per department | 21 |
| `products` | One row per product | 49,688 |
| `orders` | One row per order | 3,421,083 |
| `order_products_prior` | One product line in one prior order | 32,434,489 |
| `order_products_train` | One product line in one train order | 1,384,617 |

For both order-product tables, the intended product-line grain is uniquely identified by:

```text
(order_id, add_to_cart_order)
```

The notebook also validates `(order_id, product_id)` as an alternate candidate key. `add_to_cart_order` represents basket position and must never be interpreted as quantity.

## 4. Execution flow

Run the notebook from top to bottom:

```text
01 - Setup
   |
   +-- 02 - Bronze Aisles
   +-- 03 - Bronze Departments
   +-- 04 - Bronze Products
   +-- 05 - Bronze Orders
   +-- 06 - Bronze Order Products Prior
   +-- 07 - Bronze Order Products Train
          |
          +-- 08 - Bronze Validation
```

The six ingestion queries are independent after Setup. In a Databricks Job, tasks 02 through 07 can run in parallel. Validation must wait until all six ingestion tasks finish successfully.

## 5. Query documentation

### 01 - Setup

**Purpose:** Create the three pipeline schemas and confirm that the source folder contains exactly the six approved CSV files.

**Actions:**

- Creates `workspace.instacart_bronze` if it does not already exist.
- Creates `workspace.instacart_silver` if it does not already exist.
- Creates `workspace.instacart_gold` if it does not already exist.
- Defines the six expected filenames.
- Reads the source folder as binary-file metadata to identify the available CSV filenames.
- Uses left anti joins to identify missing and unexpected files.
- Uses `assert_true` to stop execution when the source file set is incomplete or incorrect.

**Output grain:** One validation summary row for the source folder.

**Expected result:**

| Metric | Expected value |
|---|---:|
| `actual_file_count` | 6 |
| `unexpected_file_count` | 0 |
| `missing_file_count` | 0 |

This check prevents the pipeline from starting with an incomplete or unintended source snapshot.

### 02 - Bronze Aisles

**Purpose:** Load the aisle reference data into a Delta table.

**Input:** `aisles.csv`  
**Output:** `workspace.instacart_bronze.aisles`  
**Grain:** One row per aisle, identified by `aisle_id`.

**Columns:**

| Column | Type | Meaning |
|---|---|---|
| `aisle_id` | `INT` | Source aisle identifier |
| `aisle` | `STRING` | Aisle name |
| `_rescued_data` | `STRING` | Databricks parsing-control information when source content cannot be represented by the declared schema |

The query uses `CREATE OR REPLACE TABLE ... AS SELECT`, which rebuilds the Delta table from the current source snapshot and updates the table schema to match the query output.

### 03 - Bronze Departments

**Purpose:** Load the department reference data into a Delta table.

**Input:** `departments.csv`  
**Output:** `workspace.instacart_bronze.departments`  
**Grain:** One row per department, identified by `department_id`.

**Columns:**

| Column | Type | Meaning |
|---|---|---|
| `department_id` | `INT` | Source department identifier |
| `department` | `STRING` | Department name |
| `_rescued_data` | `STRING` | Databricks parsing-control information |

The query first declares the Delta table and then uses `INSERT OVERWRITE`. This replaces the table contents on every complete run, preventing duplicate rows from repeated execution.

### 04 - Bronze Products

**Purpose:** Load the product master data while correctly parsing names that contain commas and quotation marks.

**Input:** `products.csv`  
**Output:** `workspace.instacart_bronze.products`  
**Grain:** One row per product, identified by `product_id`.

**Columns:**

| Column | Type | Meaning |
|---|---|---|
| `product_id` | `INT` | Source product identifier |
| `product_name` | `STRING` | Product description |
| `aisle_id` | `INT` | Source aisle reference |
| `department_id` | `INT` | Source department reference |
| `_rescued_data` | `STRING` | Databricks parsing-control information |

The parser explicitly sets the double quotation mark as both `quote` and `escape`. This is necessary because some product names contain embedded quotation marks and commas. Without the correct parser settings, fields can shift and required identifiers such as `aisle_id` and `department_id` can become null.

The query uses `CREATE OR REPLACE TABLE ... AS SELECT` so a previously created table with an outdated schema cannot block the corrected reload.

### 05 - Bronze Orders

**Purpose:** Load order-level customer and ordering-context data.

**Input:** `orders.csv`  
**Output:** `workspace.instacart_bronze.orders`  
**Grain:** One row per order, identified by `order_id`.

**Columns:**

| Column | Type | Meaning |
|---|---|---|
| `order_id` | `INT` | Source order identifier |
| `user_id` | `INT` | Source customer identifier |
| `eval_set` | `STRING` | Source label: `prior`, `train`, or `test` |
| `order_number` | `INT` | Sequence number of the order for the customer |
| `order_dow` | `INT` | Source day-of-week code from 0 through 6 |
| `order_hour_of_day` | `INT` | Source hour from 0 through 23 |
| `days_since_prior_order` | `DOUBLE` | Days since the customer's previous order; expected to be null for the first order |
| `_rescued_data` | `STRING` | Databricks parsing-control information |

The table is declared with an explicit schema and refreshed using `INSERT OVERWRITE`.

### 06 - Bronze Order Products Prior

**Purpose:** Load product-line events from customers' prior orders.

**Input:** `order_products__prior.csv`  
**Output:** `workspace.instacart_bronze.order_products_prior`  
**Grain:** One product line in one prior order, identified by `(order_id, add_to_cart_order)`.

**Columns:**

| Column | Type | Meaning |
|---|---|---|
| `order_id` | `INT` | Source order identifier |
| `product_id` | `INT` | Source product identifier |
| `add_to_cart_order` | `INT` | Position in which the product was added to the basket |
| `reordered` | `INT` | Reorder indicator: 0 or 1 |
| `_rescued_data` | `STRING` | Databricks parsing-control information |

The query performs a complete, repeatable refresh using `INSERT OVERWRITE`. It does not infer a quantity because the source does not contain one.

### 07 - Bronze Order Products Train

**Purpose:** Load product-line events from labeled train orders.

**Input:** `order_products__train.csv`  
**Output:** `workspace.instacart_bronze.order_products_train`  
**Grain:** One product line in one train order, identified by `(order_id, add_to_cart_order)`.

The columns and meanings match the prior order-product table. Keeping prior and train as separate Bronze tables preserves source lineage. They are combined later in Silver with an `eval_set` value that identifies their origin.

The query performs a complete, repeatable refresh using `INSERT OVERWRITE`.

### 08 - Bronze Validation

**Purpose:** Produce a table-level quality summary and stop the pipeline when any Bronze table fails an important requirement.

**Output grain:** One validation summary row per Bronze table.

**Validation columns:**

| Column | Meaning |
|---|---|
| `expected_rows` | Approved row count for the static source snapshot |
| `actual_rows` | Rows loaded into the Bronze table |
| `row_difference` | `actual_rows - expected_rows`; expected to be zero |
| `null_required_ids` | Rows with a null identifier required by the table grain or relationship |
| `duplicate_primary_keys` | Extra rows violating the primary candidate key |
| `duplicate_alternate_keys` | Extra rows violating a second validated business key |
| `required_field_issues` | Rows with missing required descriptive or order-context values |
| `domain_issues` | Rows violating approved ranges or business rules |
| `rescued_rows` | Rows containing nonnull `_rescued_data` |
| `status` | `PASS` only when every issue count and row difference is zero; otherwise `FAIL` |
| `bronze_validation_check` | Pipeline-stopping assertion; null when successful because `assert_true` returns null for a true condition |

**Candidate-key checks:**

- `aisles`: `aisle_id`
- `departments`: `department_id`
- `products`: `product_id`
- `orders`: `order_id` and `(user_id, order_number)`
- order-product tables: `(order_id, add_to_cart_order)` and `(order_id, product_id)`

**Domain checks:**

- `eval_set` is `prior`, `train`, or `test`.
- `order_number >= 1`.
- `order_dow` is between 0 and 6.
- `order_hour_of_day` is between 0 and 23.
- `days_since_prior_order` is nonnegative.
- `days_since_prior_order` is null for first orders and nonnull for later orders.
- `add_to_cart_order >= 1`.
- `reordered` is 0 or 1.

**Expected result:** Six rows with `status = 'PASS'`. All issue counts and row differences should be zero.

The validation is read-only. Expressions such as `TRIM(aisle) = ''` inspect data quality but do not alter the stored Bronze value.

## 6. Why `_rescued_data` is retained

`_rescued_data` is not a column in the original CSV files. It is generated by Databricks because the ingestion queries specify `rescuedDataColumn => '_rescued_data'`.

A null value is the expected successful result: no source content needed to be rescued for that row. A nonnull value signals that the parser encountered source content that did not fit the declared schema. Retaining the column provides ingestion observability and helps prevent unexpected source changes from being silently overlooked.

The column does not add extra source rows. Its storage overhead is generally small when values are null, and the validation checks it alongside other table metrics rather than running a separate large query.

`_rescued_data` does not detect every possible business-quality problem. The notebook therefore also checks nulls, duplicates, required text, and valid value ranges.

## 7. Refresh behavior and repeatability

The notebook uses complete snapshot refreshes:

- `CREATE OR REPLACE TABLE ... AS SELECT` recreates the target from the current query output.
- `INSERT OVERWRITE` replaces all rows in an already declared target table.

Both patterns prevent duplicate accumulation when the notebook is rerun. The notebook currently uses both patterns, so readers should recognize that they implement the same full-refresh objective in different forms.

For the fixed homework dataset, full refreshes are straightforward and reasonably inexpensive. For continuously arriving production data, the design would normally evolve to incremental ingestion so only new files and records are processed.

## 8. Cost, structure, and scalability assessment

### Cost

The notebook is cost-conscious for a fixed academic batch:

- It uses explicit schemas instead of schema inference on every load.
- The six ingestion tasks can run in parallel.
- Validation combines multiple quality metrics per table.
- No unnecessary Bronze joins or derived tables are created.

Exact duplicate checks on the two large order-product tables are the most computationally expensive validation operations. They are retained because correctness at the required fact grain is more important than an approximate result.

### Structure

The notebook clearly separates setup, ingestion, and validation. Each query documents its owner, name, purpose, and grain. Bronze preserves the source tables separately, including separate prior and train order-product tables.

### Scalability

The design is reliable for the approved static snapshot. It is not intended to be a continuously growing production ingestion framework because it performs full refreshes and validates hardcoded snapshot row counts. Incremental ingestion and dynamic control totals would be appropriate if the source begins delivering new files over time.

## 9. Troubleshooting

### Schema mismatch while writing a Delta table

**Cause:** An older target table has a different schema, often because `_rescued_data` was added after the table was created.

**Resolution:** Rebuild the target using the approved `CREATE OR REPLACE TABLE ... AS SELECT` pattern, or explicitly alter the target schema before using `INSERT OVERWRITE`.

### Product identifiers become null

**Cause:** A product name containing embedded quotation marks and commas was parsed using incompatible CSV quote and escape settings.

**Resolution:** Confirm that the products query includes:

```sql
quote => '"',
escape => '"'
```

Then recreate the Bronze products table and rerun Bronze validation.

### Bronze validation raises an exception

Inspect the validation metrics to identify the failed table and category:

- Nonzero `row_difference`: unexpected row count.
- Nonzero `null_required_ids`: missing required identifiers.
- Nonzero duplicate columns: candidate-key violation.
- Nonzero `required_field_issues`: missing required context.
- Nonzero `domain_issues`: invalid range or business rule.
- Nonzero `rescued_rows`: parsing or schema issue.

Correct the source-reading problem and rerun the affected Bronze ingestion query before rerunning Validation. Do not silently filter failed source rows from Bronze.

## 10. Handoff to Silver

After all six Bronze rows return `PASS`, the Silver layer can:

- retain the five logical entities: aisles, departments, products, orders, and order products;
- combine prior and train order-product records with `UNION ALL`;
- preserve an `eval_set` field to identify source lineage;
- validate relationships from products to aisles and departments;
- validate relationships from order-product events to orders and products; and
- enforce the required business ranges and first-order date logic before Gold modeling.

Bronze validation confirms ingestion quality. Silver remains responsible for logical integration and relationship validation.
