# Data Model Documentation

**Engineer Instacart — Dimensional Star Schema**

---

## 1. Business Process

The data model represents the **Instacart online grocery purchasing process**, capturing customer orders and product purchases over time.

**Core Business Events:**
* Customers place orders for grocery products
* Each order contains one or more products
* Products are organized into aisles and departments
* Orders occur at specific times (day of week, hour of day)
* Customers may reorder products they've purchased before

**Business Value:**
Understanding purchasing patterns enables:
* Product assortment optimization
* Inventory planning
* Marketing campaign targeting
* Cross-sell and upsell opportunities
* Customer retention strategies

---

## 2. Dimensional Modeling Approach

**Methodology**: Star Schema (Kimball Methodology)

**Design Goals:**
* **Query Performance**: Denormalized dimensions for fast filtering and aggregation
* **Business Clarity**: Human-readable dimension attributes (day names, time buckets)
* **Analytical Flexibility**: Support ad-hoc queries across all business dimensions
* **Scalability**: 33.8M fact rows with optimized joins

---

## 3. Fact Table: `fact_order_items`

### Grain

**"One row represents one product in one order."**

This is an **order line item** grain, the most atomic level of transactional data available.

### Schema

| Column | Data Type | Role | Description |
|--------|-----------|------|-------------|
| `order_item_key` | BIGINT | PK | Surrogate key (auto-generated) |
| `order_key` | INT | FK | Foreign key to dim_orders |
| `product_key` | INT | FK | Foreign key to dim_products |
| `customer_key` | INT | FK | Foreign key to dim_customers |
| `add_to_cart_order` | INT | Measure | Sequence number (1, 2, 3...) indicating when product was added to cart |
| `is_reordered` | INT | Measure | Binary flag: 1 = customer reordered this product, 0 = first-time purchase |
| `source_system` | STRING | Lineage | 'prior' or 'train' (tracks source dataset) |
| `loaded_at` | TIMESTAMP | Metadata | ETL timestamp |

### Primary Key

* **Surrogate Key**: `order_item_key`
* **Natural Key**: (`order_key`, `product_key`) — composite unique identifier

### Foreign Keys

* `order_key` → `dim_orders.order_key`
* `product_key` → `dim_products.product_key`
* `customer_key` → `dim_customers.customer_key`

### Measures

1. **`add_to_cart_order`** (Semi-Additive)
   * **Type**: Integer sequence (1, 2, 3...)
   * **Business Meaning**: Position of product in shopping cart
   * **Analysis Use**: Understand product priority in purchase decision
   * **Aggregations**: MIN (first item), MAX (last item), AVG (average position)

2. **`is_reordered`** (Fully Additive)
   * **Type**: Binary indicator (0 or 1)
   * **Business Meaning**: Whether customer previously purchased this product
   * **Analysis Use**: Calculate reorder rates, identify loyal customers, repeat purchase behavior
   * **Aggregations**: SUM (reorder count), AVG (reorder rate), COUNT (total purchases)

### Fact Table Statistics

* **Row Count**: 33,819,103 order line items
* **Distinct Orders**: 3,346,083
* **Distinct Products**: 49,687
* **Distinct Customers**: 206,209
* **Average Items per Order**: ~10.1 products
* **Reorder Rate**: ~40-85% (varies by product)

---

## 4. Dimension Tables

### 4.1 `dim_products` — Product Dimension

**Purpose**: Describes products with denormalized hierarchical attributes (department → aisle → product)

#### Grain

**"One row represents one product."**

#### Schema

| Column | Data Type | Role | Description |
|--------|-----------|------|-------------|
| `product_key` | INT | PK | Primary key (= product_id) |
| `product_id` | INT | Natural Key | Original source product identifier |
| `product_name` | STRING | Attribute | Full product name (e.g., "Organic Hass Avocado") |
| `aisle_id` | INT | Attribute | Aisle identifier (foreign key concept, denormalized) |
| `aisle_name` | STRING | Attribute | Aisle name (e.g., "fresh fruits") |
| `department_id` | INT | Attribute | Department identifier (foreign key concept, denormalized) |
| `department_name` | STRING | Attribute | Department name (e.g., "produce") |
| `product_hierarchy` | STRING | Attribute | Full hierarchy: "department / aisle / product" |
| `loaded_at` | TIMESTAMP | Metadata | ETL timestamp |

#### Key Attributes

* **Product Hierarchy**: Department (21) → Aisle (134) → Product (49,687)
* **Denormalization**: Aisle and department names included directly (no snowflake schema)
* **Business Value**: Enables drill-down analysis (department → aisle → product)

#### Statistics

* **Row Count**: 49,687 products
* **Departments**: 21 (e.g., produce, dairy eggs, snacks)
* **Aisles**: 134 (e.g., fresh fruits, packaged cheese, energy granola bars)

---

### 4.2 `dim_customers` — Customer Dimension

**Purpose**: Describes customers with pre-aggregated behavioral metrics

#### Grain

**"One row represents one customer."**

#### Schema

| Column | Data Type | Role | Description |
|--------|-----------|------|-------------|
| `customer_key` | INT | PK | Primary key (= user_id) |
| `user_id` | INT | Natural Key | Original source customer identifier |
| `first_order_number` | INT | Attribute | Always 1 (first order in sequence) |
| `total_orders` | INT | Metric | Maximum order_number for customer (lifetime orders) |
| `total_order_count` | BIGINT | Metric | COUNT(DISTINCT order_id) |
| `avg_days_between_orders` | DOUBLE | Metric | Average days_since_prior_order |
| `loaded_at` | TIMESTAMP | Metadata | ETL timestamp |

#### Key Attributes

* **Pre-Aggregated Metrics**: Customer lifetime value indicators computed once in dimension
* **Order Frequency**: `avg_days_between_orders` indicates purchase cadence
* **Customer Segmentation**: Can segment by total_orders (1-time vs repeat customers)

#### Statistics

* **Row Count**: 206,209 customers
* **Average Orders per Customer**: ~16.2 orders
* **Average Days Between Orders**: ~17 days [TO CONFIRM]

---

### 4.3 `dim_orders` — Order Dimension

**Purpose**: Describes orders with temporal and behavioral attributes

#### Grain

**"One row represents one order."**

#### Schema

| Column | Data Type | Role | Description |
|--------|-----------|------|-------------|
| `order_key` | INT | PK | Primary key (= order_id) |
| `order_id` | INT | Natural Key | Original source order identifier |
| `user_id` | INT | Attribute | Customer who placed the order |
| `order_number` | INT | Attribute | Sequence number for this customer (1, 2, 3...) |
| `order_dow` | INT | Attribute | Day of week (0=Sunday, 6=Saturday) |
| `day_of_week_name` | STRING | Attribute | Human-readable day name ("Sunday", "Monday", etc.) |
| `order_hour_of_day` | INT | Attribute | Hour of order (0-23) |
| `time_of_day_bucket` | STRING | Attribute | "Morning" (5-11), "Afternoon" (12-16), "Evening" (17-21), "Night" (22-4) |
| `days_since_prior_order` | DOUBLE | Attribute | Days elapsed since customer's previous order (NULL for first order) |
| `loaded_at` | TIMESTAMP | Metadata | ETL timestamp |

#### Key Attributes

* **Temporal Dimensions**: Day of week and hour enable time-based analysis
* **Human-Readable**: Day names and time buckets improve business user experience
* **Customer Journey**: `order_number` and `days_since_prior_order` track purchase cadence

#### Statistics

* **Row Count**: 3,346,083 orders
* **Peak Day**: Sunday (~585K orders)
* **Peak Hour**: 10-11 AM and 2-3 PM
* **Avg Days Between Orders**: ~17 days [TO CONFIRM]

---

## 5. Star Schema Diagram

```
                        dim_products
                      (49,687 products)
                    +-------------------+
                    | product_key (PK)  |
                    | product_name      |
                    | aisle_name        |
                    | department_name   |
                    | product_hierarchy |
                    +-------------------+
                             |
                             | product_key (FK)
                             |
                             v

                   fact_order_items
                  (33.8M line items)
              +------------------------+
              | order_item_key (PK)    |
order_key --> | order_key (FK)         | <-- customer_key
              | product_key (FK)       |
              | customer_key (FK)      |
              | add_to_cart_order      |
              | is_reordered           |
              +------------------------+
                  |                |
                  |                |
                  v                v

         dim_orders          dim_customers
      (3.3M orders)          (206K customers)
  +------------------+     +----------------------+
  | order_key (PK)   |     | customer_key (PK)    |
  | order_number     |     | total_orders         |
  | day_of_week_name |     | total_order_count    |
  | order_hour       |     | avg_days_between     |
  | time_bucket      |     +----------------------+
  +------------------+
```

### Relationships

* **fact_order_items** → **dim_products**: Many-to-One (product_key)
* **fact_order_items** → **dim_orders**: Many-to-One (order_key)
* **fact_order_items** → **dim_customers**: Many-to-One (customer_key)

---

## 6. Dimensional Model Integrity

### Referential Integrity

All foreign keys in `fact_order_items` have corresponding records in dimension tables:

* **fact → dim_products**: 0 orphans (✓)
* **fact → dim_orders**: 0 orphans (✓)
* **fact → dim_customers**: 0 orphans (✓)

### Primary Key Uniqueness

All dimension primary keys are unique:

* **dim_products.product_key**: 49,687 unique values (✓)
* **dim_customers.customer_key**: 206,209 unique values (✓)
* **dim_orders.order_key**: 3,346,083 unique values (✓)

### Fact Table Grain Uniqueness

The natural key (`order_key`, `product_key`) is unique across all 33.8M rows (✓)

---

## 7. Modeling Decisions

### Why Star Schema?

**Decision**: Use star schema (not snowflake schema)

**Rationale:**
* **Query Performance**: Denormalized dimensions reduce join complexity
* **Simplicity**: Business users can understand flat dimension tables
* **Flexibility**: Product hierarchy (department/aisle) is stable and not deeply nested

**Trade-off**: Some data redundancy (aisle_name repeated for each product) in exchange for performance

---

### Why This Fact Table Grain?

**Decision**: Order line item grain (one row per product per order)

**Rationale:**
* **Most Atomic**: Preserves maximum analytical flexibility
* **Supports All BQs**: Can aggregate up to any level (product, order, customer, department)
* **Market Basket Analysis**: Enables product pair analysis (self-join on order_key)
* **Time Series**: Enables temporal analysis by order date/time

**Alternative Considered**: Order header grain (one row per order) — rejected because it loses product-level detail

---

### Why Pre-Aggregate Customer Metrics in Dimension?

**Decision**: Include `total_orders`, `avg_days_between_orders` in `dim_customers`

**Rationale:**
* **Performance**: Avoids expensive aggregations in every query
* **Simplicity**: Business users can filter on customer segments directly
* **Static**: Customer lifetime metrics don't change within a data load cycle

**Trade-off**: Dimension must be rebuilt if fact table changes (acceptable for batch pipeline)

---

### Why Denormalize Product Hierarchy?

**Decision**: Include aisle_name and department_name in `dim_products`

**Rationale:**
* **Query Simplicity**: Single JOIN to get full product context (no snowflake)
* **Business Clarity**: Users see "produce" instead of department_id=4
* **Performance**: Avoids additional JOINs to aisle/department lookup tables

**Trade-off**: Redundancy (aisle names repeated) vs. performance and simplicity

---

### Why Surrogate Key in Fact Table?

**Decision**: Use `order_item_key` as surrogate primary key

**Rationale:**
* **Uniqueness**: Guarantees unique row identifier even if natural key has issues
* **Simplicity**: Single-column PK easier to reference than composite (order_key, product_key)
* **Future-Proofing**: Allows for slowly changing dimensions (SCD) in future

**Alternative**: Composite natural key (order_key, product_key) — also valid, but less flexible

---

### Why Temporal Attributes in Order Dimension?

**Decision**: Add `day_of_week_name` and `time_of_day_bucket` to `dim_orders`

**Rationale:**
* **Business User Experience**: "Sunday" is clearer than dow=0
* **Simplified Queries**: No need for CASE statements in every query
* **Consistent Bucketing**: Standardizes time-of-day logic across all analyses

**Trade-off**: Dimension rebuild required if bucketing logic changes

---

## 8. How the Model Answers Business Questions

### BQ1: Which products and departments are purchased most frequently?

```sql
SELECT 
  p.department_name,
  p.product_name,
  COUNT(*) AS total_orders,
  COUNT(DISTINCT f.customer_key) AS unique_customers,
  AVG(CAST(f.is_reordered AS DOUBLE)) * 100 AS reorder_rate_pct
FROM fact_order_items f
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.department_name, p.product_name
ORDER BY total_orders DESC;
```

**Model Support**:
* `dim_products` provides department/product names
* `fact_order_items` provides purchase transactions
* `is_reordered` measure calculates reorder rate

---

### BQ2: How does purchasing behavior change by day and hour?

```sql
SELECT 
  o.day_of_week_name,
  o.order_hour_of_day,
  COUNT(DISTINCT f.order_key) AS total_orders,
  AVG(items_per_order) AS avg_items_per_order
FROM fact_order_items f
JOIN dim_orders o ON f.order_key = o.order_key
GROUP BY o.day_of_week_name, o.order_hour_of_day
ORDER BY o.order_dow, o.order_hour_of_day;
```

**Model Support**:
* `dim_orders` provides temporal attributes (day, hour, buckets)
* `fact_order_items` provides order-level transactions

---

### BQ3: Which products have the highest reorder behavior?

```sql
SELECT 
  p.product_name,
  COUNT(*) AS total_purchases,
  SUM(CAST(f.is_reordered AS INT)) AS reorder_count,
  ROUND(SUM(CAST(f.is_reordered AS INT)) * 100.0 / COUNT(*), 2) AS reorder_rate_pct
FROM fact_order_items f
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
HAVING COUNT(*) >= 100
ORDER BY reorder_rate_pct DESC;
```

**Model Support**:
* `is_reordered` measure directly supports reorder rate calculation
* `dim_products` provides product context

---

### BQ4: What are the most common product pairs?

```sql
SELECT 
  p1.product_name AS product_1,
  p2.product_name AS product_2,
  COUNT(DISTINCT f1.order_key) AS orders_with_both
FROM fact_order_items f1
JOIN fact_order_items f2 ON f1.order_key = f2.order_key
  AND f1.product_key < f2.product_key
JOIN dim_products p1 ON f1.product_key = p1.product_key
JOIN dim_products p2 ON f2.product_key = p2.product_key
GROUP BY p1.product_name, p2.product_name
HAVING COUNT(DISTINCT f1.order_key) >= 100
ORDER BY orders_with_both DESC;
```

**Model Support**:
* Order line item grain enables self-join on `order_key`
* `dim_products` provides product names for both items

---

## 9. Model Evolution and Future Enhancements

### Potential Enhancements

1. **Date Dimension** (`dim_date`)
   * Add proper date dimension with fiscal calendar, holidays, week-of-year
   * Current: Order dimension has temporal attributes but no true date key

2. **Slowly Changing Dimensions** (SCD)
   * Track product name changes, department reassignments over time
   * Current: Dimensions are Type 1 (overwrite)

3. **Aggregate Fact Tables**
   * Daily/weekly product sales summaries for faster reporting
   * Current: Pre-aggregated analytics tables (`gold_*`) serve this purpose

4. **Additional Measures**
   * Product price, order total, discount amount (if source data becomes available)
   * Current: Only count-based metrics (orders, reorders)

5. **Conformed Dimensions**
   * If additional fact tables are added (e.g., inventory, promotions)
   * Share `dim_products`, `dim_customers`, `dim_orders` across facts

---

## 10. Model Validation Checklist

✅ **Fact table grain is clearly defined**: One row per product per order  
✅ **Primary keys are unique**: All dimension PKs have no duplicates  
✅ **Foreign keys are valid**: All fact FKs have matching dimension records  
✅ **Measures are additive or semi-additive**: `is_reordered` additive, `add_to_cart_order` semi-additive  
✅ **Dimensions are denormalized**: Product hierarchy flattened into dim_products  
✅ **Business-friendly attributes**: Day names, time buckets, product hierarchies  
✅ **Model answers all business questions**: BQ1-BQ4 fully supported  
✅ **Performance optimized**: Pre-aggregated tables for dashboard  
✅ **Documented and validated**: All tables documented with row counts and data quality checks  

---

**Last Updated**: September 2, 2026  
**Document Owner**: Tina (Cristina)  
**Project**: Engineer Instacart
