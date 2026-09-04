# Data Model Documentation

**Instacart Data Engineering Pipeline — Dimensional Star Schema**

---

## 1. Business Process

The data model represents the **Instacart online grocery purchasing process**, capturing customer orders and product purchases.

**Core Business Events:**
* Customers place orders for grocery products
* Each order contains one or more products
* Products are organized into aisles and departments
* Orders occur at specific times (day of week, hour of day)
* Customers may reorder products they've purchased before

**Business Value:**
* Product assortment optimization
* Inventory planning
* Marketing campaign targeting
* Cross-sell and upsell opportunities
* Customer retention strategies

---

## 2. Dimensional Modeling Approach

**Methodology**: Star Schema (Kimball Methodology)

**Design Goals:**
* **Query Performance**: Denormalized dimensions for fast aggregation
* **Business Clarity**: Human-readable dimension attributes (day names, time buckets)
* **Analytical Flexibility**: Support ad-hoc queries across all business dimensions
* **Referential Integrity**: Unity Catalog PK/FK constraints
* **Scalability**: 33.8M fact rows with optimized joins

---

## 3. Fact Table: `fact_order_product`

**Catalog/Schema**: `workspace.instacart_gold`

### Grain

**"One row represents one product in one order."**

This is an **order line item** grain, the most atomic transactional level.

### Schema

| Column | Data Type | Role | Description |
|--------|-----------|------|-------------|
| `order_id` | INT | PK/FK | Composite PK component, FK to dim_order |
| `product_id` | INT | FK | FK to dim_product |
| `add_to_cart_order` | INT | PK/Measure | Composite PK component, cart sequence |
| `reordered` | BOOLEAN | Measure | 1 = reorder, 0 = first-time purchase |
| `user_id` | INT | Attribute | Denormalized customer identifier |
| `source_system` | STRING | Lineage | 'prior' or 'train' |
| `loaded_at` | TIMESTAMP | Metadata | Load timestamp |

### Primary Key

* **Composite**: (`order_id`, `add_to_cart_order`)
* **Unity Catalog Constraint**: `fact_order_product_pk`
* **Rationale**: Uniquely identifies each product in each order

### Foreign Keys

* **product_id → dim_product.product_id**
  * **Unity Catalog Constraint**: `fact_order_product_product_fk`
  * Ensures every product in an order exists in product dimension

* **order_id → dim_order.order_id**
  * **Unity Catalog Constraint**: `fact_order_product_order_fk`
  * Ensures every order line item links to a valid order

### Measures

#### 1. `add_to_cart_order` (Semi-Additive)
* **Type**: Integer sequence (1, 2, 3, ...)
* **Business Meaning**: Position of product in shopping cart
* **Analysis Use Cases**:
  * Identify which products customers add first/last
  * Understand product priority in purchase decision
  * Analyze shopping cart build patterns
* **Aggregations**: MIN (first item), MAX (last item), AVG (average position)

#### 2. `reordered` (Fully Additive)
* **Type**: Boolean (TRUE/FALSE, stored as 1/0)
* **Business Meaning**: Whether customer previously purchased this product
* **Analysis Use Cases**:
  * Calculate reorder rates by product, department, or customer
  * Identify products with high customer loyalty
  * Measure repeat purchase behavior
  * Segment customers by reorder frequency
* **Aggregations**:
  * SUM(reordered) → total reorder count
  * AVG(reordered) × 100 → reorder rate percentage
  * COUNT(*) → total purchases

### Fact Table Statistics

* **Row Count**: 33,819,103 order line items
* **Distinct Orders**: 3,346,083
* **Distinct Products**: 49,687
* **Distinct Customers**: 206,209
* **Average Items per Order**: ~10.1 products
* **Overall Reorder Rate**: ~59%

---

## 4. Dimension Tables

### 4.1 `dim_product` — Product Dimension

**Catalog/Schema**: `workspace.instacart_gold`

#### Grain

**"One row represents one product."**

#### Schema

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `product_id` | INT | NOT NULL | Primary key |
| `product_name` | STRING | Yes | Product name |
| `aisle_id` | INT | Yes | Aisle identifier |
| `aisle_name` | STRING | Yes | Aisle name (e.g., "fresh fruits") |
| `department_id` | INT | Yes | Department identifier |
| `department_name` | STRING | Yes | Department name (e.g., "produce") |
| `product_hierarchy` | STRING | Yes | Concatenated: "department / aisle / product" |
| `loaded_at` | TIMESTAMP | Yes | Load timestamp |

#### Primary Key

* **product_id** (Unity Catalog constraint: `dim_product_pk`)
* **Uniqueness**: 49,687 distinct products
* **Natural Key**: product_id (no surrogate key needed)

#### Purpose

Product dimension with **denormalized hierarchy** to support:
* Filtering by department, aisle, or product
* Drill-down analysis (department → aisle → product)
* Product hierarchy navigation
* Fast joins without additional lookups

#### Product Hierarchy

The `product_hierarchy` column provides a full breadcrumb path:

**Example**: "produce / fresh fruits / Banana"

**Benefits**:
* Single-column search for hierarchy navigation
* Simplified dashboard filters
* Human-readable product context

#### Statistics

* **Total Products**: 49,687
* **Departments**: 21
* **Aisles**: 134
* **Average Products per Aisle**: 371
* **Average Products per Department**: 2,366

---

### 4.2 `dim_order` — Order Dimension

**Catalog/Schema**: `workspace.instacart_gold`

#### Grain

**"One row represents one order."**

#### Schema

| Column | Data Type | Nullable | Description |
|--------|-----------|----------|-------------|
| `order_id` | INT | NOT NULL | Primary key |
| `user_id` | INT | Yes | Customer identifier |
| `eval_set` | STRING | Yes | 'prior' or 'train' |
| `order_number` | INT | Yes | Customer's order sequence (1, 2, 3, ...) |
| `order_dow` | INT | Yes | Day of week (0=Sunday, 6=Saturday) |
| `day_of_week_name` | STRING | Yes | 'Sunday', 'Monday', etc. |
| `order_hour_of_day` | INT | Yes | Hour (0-23) |
| `time_of_day_bucket` | STRING | Yes | 'Night (12AM-6AM)', 'Morning (6AM-12PM)', etc. |
| `days_since_prior_order` | DOUBLE | Yes | Days since last order (NULL for first) |
| `loaded_at` | TIMESTAMP | Yes | Load timestamp |

#### Primary Key

* **order_id** (Unity Catalog constraint: `dim_order_pk`)
* **Uniqueness**: 3,346,083 distinct orders
* **Natural Key**: order_id (no surrogate key needed)

#### Purpose

Order dimension with **temporal attributes** to support:
* Time-based analysis (day of week, hour of day)
* Customer order sequence tracking
* Purchase frequency analysis
* Temporal pattern identification

#### Derived Attributes

##### 1. `day_of_week_name`

Derived from `order_dow`:

| order_dow | day_of_week_name |
|-----------|------------------|
| 0 | Sunday |
| 1 | Monday |
| 2 | Tuesday |
| 3 | Wednesday |
| 4 | Thursday |
| 5 | Friday |
| 6 | Saturday |

##### 2. `time_of_day_bucket`

Derived from `order_hour_of_day`:

| Hour Range | time_of_day_bucket |
|------------|--------------------|
| 0-5 | Night (12AM-6AM) |
| 6-11 | Morning (6AM-12PM) |
| 12-17 | Afternoon (12PM-6PM) |
| 18-23 | Evening (6PM-12AM) |

**Benefits**:
* Simplified temporal aggregation
* Business-friendly time groupings
* Dashboard filters for time periods

#### Customer Attributes

**Note**: This dimension includes customer-related attributes (`user_id`, `order_number`) but is **not** a separate customer dimension.

**Design Decision**: Customer attributes are embedded in the order dimension because:
* Orders are the primary grain of analysis
* Customer metrics (total orders, frequency) can be derived via aggregation
* Simplified star schema (2 dimensions + 1 fact)
* Avoids multi-hop joins for common queries

**Customer Analysis**:
* Customer lifetime orders: `MAX(order_number) by user_id`
* Purchase frequency: `AVG(days_since_prior_order) by user_id`
* Customer segmentation: Aggregate order-level metrics

#### Statistics

* **Total Orders**: 3,346,083
* **Unique Customers**: 206,209
* **Average Orders per Customer**: ~16.2
* **Average Days Between Orders**: ~17.1 days
* **Peak Order Hour**: 10 AM
* **Peak Order Day**: Sunday

---

## 5. Star Schema Relationships

### Entity-Relationship Diagram

```
           dim_product
           ┌───────────────────────────┐
           │ PK: product_id            │
           │ product_name              │
           │ aisle_name                │
           │ department_name           │
           │ product_hierarchy         │
           └───────────────────────────┘
                       │
                       │ 1
                       │
                       │ product_id (FK)
                       │
                       │ N
                       ▼
        fact_order_product
        ┌───────────────────────────────────┐
        │ PK: (order_id, add_to_cart_order) │
        │ FK: product_id                    │
        │ FK: order_id                      │
        │ Measures:                         │
        │  - add_to_cart_order              │
        │  - reordered                      │
        └───────────────────────────────────┘
                       ▲
                       │ N
                       │
                       │ order_id (FK)
                       │
                       │ 1
                       │
            dim_order
            ┌──────────────────────────┐
            │ PK: order_id             │
            │ user_id                  │
            │ day_of_week_name         │
            │ time_of_day_bucket       │
            │ order_number             │
            └──────────────────────────┘
```

### Relationship Cardinalities

#### `fact_order_product` ← `dim_product`

* **Type**: Many-to-One
* **Cardinality**: Many fact rows → One product
* **Business Rule**: Each order line item references exactly one product
* **Enforcement**: Unity Catalog FK constraint `fact_order_product_product_fk`

#### `fact_order_product` ← `dim_order`

* **Type**: Many-to-One
* **Cardinality**: Many fact rows → One order
* **Business Rule**: Each order line item belongs to exactly one order
* **Enforcement**: Unity Catalog FK constraint `fact_order_product_order_fk`

### Join Patterns

#### Standard Analytics Query

```sql
SELECT 
  dp.department_name,
  dp.aisle_name,
  do.day_of_week_name,
  COUNT(*) AS total_purchases,
  COUNT(DISTINCT f.order_id) AS total_orders,
  COUNT(DISTINCT do.user_id) AS unique_customers,
  AVG(CAST(f.reordered AS INT)) * 100 AS reorder_rate_pct
FROM workspace.instacart_gold.fact_order_product f
INNER JOIN workspace.instacart_gold.dim_product dp 
  ON f.product_id = dp.product_id
INNER JOIN workspace.instacart_gold.dim_order do 
  ON f.order_id = do.order_id
GROUP BY dp.department_name, dp.aisle_name, do.day_of_week_name;
```

#### Customer Analysis Query

```sql
SELECT 
  do.user_id,
  COUNT(DISTINCT do.order_id) AS total_orders,
  MAX(do.order_number) AS order_sequence_length,
  AVG(do.days_since_prior_order) AS avg_days_between_orders,
  COUNT(DISTINCT f.product_id) AS unique_products_purchased,
  AVG(CAST(f.reordered AS INT)) * 100 AS customer_reorder_rate
FROM workspace.instacart_gold.dim_order do
INNER JOIN workspace.instacart_gold.fact_order_product f 
  ON do.order_id = f.order_id
GROUP BY do.user_id;
```

---

## 6. Business Questions Supported

### Question 1: Which products and departments are purchased most frequently?

**Dimensions Used**: `dim_product` (department_name, product_name)

**Measures Used**: COUNT(*), COUNT(DISTINCT order_id), reordered

**Query Pattern**: Aggregate fact by product dimension, order by purchase count

### Question 2: How does customer purchasing behavior change by day of week and hour of day?

**Dimensions Used**: `dim_order` (day_of_week_name, order_hour_of_day, time_of_day_bucket)

**Measures Used**: COUNT(DISTINCT order_id), COUNT(*), AVG(items per order)

**Query Pattern**: Aggregate fact by temporal dimensions

### Question 3: Which products have the highest reorder behavior?

**Dimensions Used**: `dim_product` (product_name, department_name)

**Measures Used**: SUM(reordered), AVG(reordered), COUNT(*)

**Query Pattern**: Aggregate reordered measure by product

### Question 4: What are common product pairs purchased together? (Future)

**Dimensions Used**: `dim_product` (for both products in the pair)

**Measures Used**: COUNT(DISTINCT order_id) where both products exist

**Query Pattern**: Self-join fact table on order_id, aggregate by product pairs

---

## 7. Data Quality & Integrity

### Unity Catalog Constraints

**Primary Keys**:
* `dim_product.product_id` → Enforced, 0 duplicates ✓
* `dim_order.order_id` → Enforced, 0 duplicates ✓
* `fact_order_product (order_id, add_to_cart_order)` → Enforced, 0 duplicates ✓

**Foreign Keys**:
* `fact_order_product.product_id → dim_product.product_id` → Enforced, 0 orphans ✓
* `fact_order_product.order_id → dim_order.order_id` → Enforced, 0 orphans ✓

### Validation Results

**Row Count Integrity**:
```
Silver → Gold Reconciliation:
  silver_products (49,687) → dim_product (49,687) ✓
  silver_orders (3,346,083) → dim_order (3,346,083) ✓
  silver_order_products (33,819,106) → fact_order_product (33,819,103) ⚠ (3 orphans filtered)
```

**Referential Integrity**:
* All fact rows successfully join to both dimensions ✓
* 3 orphan products filtered upstream (documented data quality issue)

**Measure Validation**:
* `reordered`: All values are 0 or 1 ✓
* `add_to_cart_order`: All values > 0 ✓
* No NULL values in primary key columns ✓

---

## 8. Design Decisions

### Decision 1: Composite Primary Key in Fact Table

**Choice**: (`order_id`, `add_to_cart_order`) vs. surrogate key

**Rationale**:
* Natural composite key uniquely identifies each order line item
* Avoids unnecessary surrogate key generation
* Preserves semantic meaning in primary key
* `add_to_cart_order` serves dual purpose: PK component + measure

### Decision 2: No Separate Customer Dimension

**Choice**: Embed customer attributes in `dim_order` vs. create `dim_customer`

**Rationale**:
* Orders are the primary analysis grain
* Customer metrics easily derived via aggregation
* Avoids multi-hop joins for common queries
* Simplified star schema (2 dimensions instead of 3)

**Trade-off**: Repeats `user_id` across multiple orders, but:
* Storage cost is minimal (INT column)
* Query performance is faster (no additional join)
* Can be refactored to separate dimension in Phase 2

### Decision 3: Denormalized Product Hierarchy

**Choice**: Embed aisle/department names in `dim_product` vs. snowflake schema

**Rationale**:
* Faster queries (no joins to aisle/department tables)
* Simplified dashboard design
* Aisle/department are descriptive, not frequently updated
* Star schema best practice (denormalize dimensions)

### Decision 4: Derived Temporal Attributes

**Choice**: Pre-compute `day_of_week_name` and `time_of_day_bucket` vs. compute at query time

**Rationale**:
* Improved query performance (no CASE statements in every query)
* Business-friendly column names
* Consistent bucketing logic across all queries
* Simplified dashboard filters

---

## 9. Future Enhancements

### Phase 2: Dimensional Model Evolution

#### Add `dim_date` Dimension
* Date key (YYYYMMDD)
* Fiscal calendar attributes
* Holiday indicators
* Week/month/quarter hierarchies

#### Split Customer Dimension
* Create `dim_customer` separate from orders
* Add customer lifetime metrics
* Implement SCD Type 2 for customer segmentation changes

#### Aggregate Fact Tables
* Daily/monthly aggregates for dashboard performance
* Pre-compute reorder rates by product/customer
* Market basket analysis (product pairs)

### Phase 3: Advanced Analytics

* Implement SCD Type 2 for product price tracking
* Add product lifecycle attributes (new/mature/declining)
* Customer RFM (Recency, Frequency, Monetary) segmentation
* Predictive measures (propensity to reorder)

---

## 10. Star Schema Best Practices Applied

✓ **Fact Grain Clearly Defined**: Order line item (one product per order)  
✓ **Additive Measures**: `reordered` is fully additive  
✓ **Denormalized Dimensions**: Product hierarchy embedded  
✓ **Surrogate vs. Natural Keys**: Natural keys used where appropriate  
✓ **Slowly Changing Dimensions**: Not needed (no historical changes)  
✓ **Referential Integrity**: Unity Catalog constraints enforced  
✓ **Conformed Dimensions**: Dimensions can be reused across multiple fact tables  
✓ **Business-Friendly Naming**: Readable column names and derived attributes  

---

**Last Updated**: 2026-09-04  
**Data Model Version**: 1.0 (workspace.instacart_gold implementation)  
**Maintained By**: FTW Data Engineering Batch 12
