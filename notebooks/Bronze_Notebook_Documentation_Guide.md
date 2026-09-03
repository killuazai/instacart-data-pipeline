# Instacart Bronze Notebook — Design Explanation

**Owner:** Nadine  
**Based on:** `Bronze (2).ipynb`

## Why I structured the notebook this way

I organized the notebook into three stages: **Setup → Load the six CSV files → Validate Bronze**. Separating preparation, ingestion, and checking makes the process easier to follow.

The goal is a typed source copy in `workspace.instacart_bronze`, not cleaned data. The notebook does not remove duplicates, replace missing values, or combine tables. It detects problems before Silver processing.

## 01 — Setup

I create the Bronze, Silver, and Gold schemas to organize the pipeline. This only prepares the Silver and Gold locations; their tables are not loaded here.

I compare the available CSV filenames with the six approved filenames. This detects missing or unexpected CSVs. `assert_true` raises an error if the file checks fail.

## 02–07 — Bronze ingestion: one table per CSV

I keep one Bronze table for each source CSV so it is easy to trace a table back to its original file.

| Query | Bronze table | What one row represents | Expected rows |
|---|---|---|---:|
| 02 — Bronze Aisles | `aisles` | One aisle, identified by `aisle_id` | 134 |
| 03 — Bronze Departments | `departments` | One department, identified by `department_id` | 21 |
| 04 — Bronze Products | `products` | One product, identified by `product_id` | 49,688 |
| 05 — Bronze Orders | `orders` | One order, identified by `order_id` | 3,421,083 |
| 06 — Bronze Order Products Prior | `order_products_prior` | One product line in a prior order | 32,434,489 |
| 07 — Bronze Order Products Train | `order_products_train` | One product line in a train order | 1,384,617 |

Both order-product tables use `(order_id, add_to_cart_order)` as their intended unique grain. Basket position is **not quantity**. Prior and train remain separate until Silver so their source is clear.

### Why the ingestion queries use these options

- **Explicit schema:** Declares the intended data types instead of guessing them.
- **`header => true`:** Treats the first CSV row as column names.
- **`USING DELTA`:** Stores the ingested records as Delta tables.
- **`CREATE OR REPLACE TABLE`:** Gives all six loads a consistent full-refresh pattern. Reruns replace the data rather than append another copy, and replace outdated target schemas.
- **`USE CATALOG` and `USE SCHEMA`:** Direct unqualified table names to the correct location.
- **`_rescued_data`:** Retains parser-rescued information that does not fit the declared schema. It is generated during ingestion, not supplied by the CSV. Null means nothing was rescued, not that every quality check passed.

For **Products**, I set the double quote as both `quote` and `escape`. Earlier, a quoted product name was parsed incorrectly and its aisle and department IDs became null. Correcting the reader settings fixes ingestion without manually editing the product.

## 08 — Bronze validation

I use a table-level summary to check:

- **Row counts:** Actual rows must equal the approved snapshot counts above.
- **Required identifiers:** IDs and product-line key fields must not be null.
- **Candidate keys:** Entity IDs must be unique. Orders also check `(user_id, order_number)`. Both order-product tables check `(order_id, add_to_cart_order)` and `(order_id, product_id)`.
- **Required fields:** Names and required order-context values must not be missing.
- **Valid values:** Correct evaluation labels, day codes 0–6, hours 0–23, order numbers/basket positions at least 1, and reorder flags 0 or 1. Days since the previous order must be nonnegative, null for first orders, and present for later orders.
- **Rescued data:** No row should contain nonnull `_rescued_data`.

`PASS` means every issue count and row difference is zero. The final `assert_true` stops the query on failure. A successful run returns six `PASS` rows; the assertion column is normally null. On failure, the error can prevent the report from displaying. For diagnosis, inspect the metrics without the assertion; keep it in the pipeline version.

These checks do not clean or change Bronze. For example, `TRIM` only detects blank names here. Relationship checks remain in Silver.

## Scope and reruns

Run Setup, all six loads, then Validation. Full refreshes suit this fixed homework dataset, but reloading and checking all records becomes more expensive as data grows. This is not incremental ingestion.

Expected counts are hardcoded for this snapshot. For the approved 5,000-order stress test, update both the expected orders count and row-difference calculation to **3,426,083**. Keep `row_difference = 0` to detect unexpected extra or missing rows.

*This guide describes the supplied notebook; no notebook changes or execution were performed.*
