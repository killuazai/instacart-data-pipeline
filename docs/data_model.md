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

## 3. Fact Table: `fact_order_product`

### Grain

**"One row represents one product in one order."**

This is an **order line item** grain, the most atomic level of transactional data available.

### Schema

| Column | Data Type | Role | Description |
|--------|-----------|------|-------------|
| `order_id` | INT | PK/FK | Composite primary key, foreign key to dim_order |
| `product_id` | INT | PK/FK | Composite primary key, foreign key to dim_product |
| `add_to_cart_order` | INT | PK/Measure | Composite primary key, sequence number indicating when product was added to cart |
| `reordered` | INT | Measure | Binary flag: 1 = customer reordered this product, 0 = first-time purchase |

### Primary Key

* **Composite Natural Key**: (`order_id`, `product_id`, `add_to_cart_order`)

### Foreign Keys

* `order_id` → `dim_order.order_id`
* `product_id` → `dim_product.product_id`

### Measures

1. **`add_to_cart_order`** (Semi-Additive)
   * **Type**: Integer sequence (1, 2, 3...)
   * **Business Meaning**: Position of product in shopping cart
   * **Analysis Use**: Understand product priority in purchase decision
   * **Aggregations**: MIN (first item), MAX (last item), AVG (average position)

2. **`reordered`** (Fully Additive)
   * **Type**: Binary indicator (0 or 1)
   * **Business Meaning**: Whether customer previously purchased this product
   * **Analysis Use**: Calculate reorder rates, identify loyal customers, repeat purchase behavior
   * **Aggregations**: SUM (reorder count), AVG (reorder rate), COUNT (total purchases)

### Fact Table Statistics

* **Row Count**: 33,819,103 order line items
* **Distinct Orders**: 3,346,083
* **Distinct Products**: 49,687
* **Average Items per Order**: ~10.1 products
* **Overall Reorder Rate**: ~59%

---

## 4. Dimension Tables

### 4.1 `dim_product` — Product Dimension

**Purpose**: Describes products with denormalized hierarchical attributes (department → aisle → product)

#### Grain

**"One row represents one product."**

#### Schema

| Column | Data Type | Role | Description |
|--------|-----------|------|-------------|
| `product_id` | INT | PK | Primary key, original source product identifier |
| `product_name` | STRING | Attribute | Full product name (e.g., "Organic Hass Avocado") |
| `aisle_id` | INT | Attribute | Aisle identifier (foreign key concept, denormalized) |
| `aisle_name` | STRING | Attribute | Aisle name (e.g., "fresh fruits") |
| `department_id` | INT | Attribute | Department identifier (foreign key concept, denormalized) |
| `department_name` | STRING | Attribute | Department name (e.g., "produce") |

#### Key Attributes

* **Product Hierarchy**: Department (21) → Aisle (134) → Product (49,687)
* **Denormalization**: Aisle and department names included directly (no snowflake schema)
* **Business Value**: Enables drill-down analysis (department → aisle → product)

#### Statistics

* **Row Count**: 49,687 products
* **Departments**: 21 (e.g., produce, dairy eggs, snacks)
* **Aisles**: 134 (e.g., fresh fruits, packaged cheese, energy granola bars)

---

### 4.2 `dim_order` — Order Dimension

**Purpose**: Describes orders with temporal and behavioral attributes

#### Grain

**"One row represents one order."**

#### Schema

| Column | Data Type | Role | Description |
|--------|-----------|------|-------------|
| `order_id` | INT | PK | Primary key, original source order identifier |
| `user_id` | INT | Attribute | Customer who placed the order |
| `order_number` | INT | Attribute | Sequence number for this customer (1, 2, 3...) |
| `order_dow` | INT | Attribute | Day of week (0=Sunday, 6=Saturday) |
| `order_hour_of_day` | INT | Attribute | Hour of order (0-23) |
| `days_since_prior_order` | DOUBLE | Attribute | Days elapsed since customer's previous order (NULL for first order) |

#### Key Attributes

* **Temporal Dimensions**: Day of week and hour enable time-based analysis
* **Customer Journey**: `order_number` and `days_since_prior_order` track purchase cadence

#### Statistics

* **Row Count**: 3,346,083 orders
* **Peak Day**: Sunday (~585K orders)
* **Peak Hour**: 10-11 AM and 2-3 PM

---

## 5. Star Schema Diagram

```
                        dim_product                         dim_order
            (49,687 products)                  (3.3M orders)
          +-------------------+              +-------------------+
          | product_id (PK)   |              | order_id (PK)     |
          | product_name      |              | user_id           |
          | aisle_name        |              | order_number      |
          | department_name   |              | order_dow         |
          +-------------------+              | order_hour_of_day |
                     |                       +-------------------+
                     | product_id (FK)                 |
                     |                                 | order_id (FK)
                     v                                 v

                          fact_order_product
                          (33.8M line items)
                     +---------------------------+
                     | order_id (PK/FK)          |
                     | product_id (PK/FK)        |
                     | add_to_cart_order (PK)    |
                     | reordered                 |
                     +---------------------------+
```

### Relationships

* **fact_order_product** → **dim_product**: Many-to-One (product_id)
* **fact_order_product** → **dim_order**: Many-to-One (order_id)

---

## 6. Dimensional Model Integrity

### Referential Integrity

All foreign keys in `fact_order_product` have corresponding records in dimension tables:

* **fact → dim_product**: 0 orphans (✓)
* **fact → dim_order**: 0 orphans (✓)

### Primary Key Uniqueness

All dimension primary keys are unique:

* **dim_product.product_id**: 49,687 unique values (✓)
* **dim_order.order_id**: 3,346,083 unique values (✓)

### Fact Table Grain Uniqueness

The composite natural key (`order_id`, `product_id`, `add_to_cart_order`) is unique across all 33.8M rows (✓)

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

### Why Denormalize Product Hierarchy?

**Decision**: Include aisle_name and department_name in `dim_product`

**Rationale:**
* **Query Simplicity**: Single JOIN to get full product context (no snowflake)
* **Business Clarity**: Users see "produce" instead of department_id=4
* **Performance**: Avoids additional JOINs to aisle/department lookup tables

**Trade-off**: Redundancy (aisle names repeated) vs. performance and simplicity

---

### Why Composite Natural Key?

**Decision**: Use composite natural key (`order_id`, `product_id`, `add_to_cart_order`) instead of surrogate key

**Rationale:**
* **Simplicity**: Natural keys directly from source system
* **Referential Integrity**: Easy to validate and trace back to source
* **No Extra Column**: Saves storage compared to adding a surrogate key

**Trade-off**: Composite keys require multi-column joins, but this is acceptable for performance with proper indexing

---

## 8. How the Model Answers Business Questions

### BQ1: Which products and departments are purchased most frequently?

```sql
SELECT 
  p.department_name,
  p.product_name,
  COUNT(*) AS total_orders,
  AVG(CAST(f.reordered AS DOUBLE)) * 100 AS reorder_rate_pct
FROM fact_order_product f
JOIN dim_product p ON f.product_id = p.product_id
GROUP BY p.department_name, p.product_name
ORDER BY total_orders DESC;
```

**Model Support**:
* `dim_product` provides department/product names
* `fact_order_product` provides purchase transactions
* `reordered` measure calculates reorder rate

---

### BQ2: How does purchasing behavior change by day and hour?

```sql
SELECT 
  o.order_dow,
  o.order_hour_of_day,
  COUNT(DISTINCT f.order_id) AS total_orders,
  COUNT(*) / COUNT(DISTINCT f.order_id) AS avg_items_per_order
FROM fact_order_product f
JOIN dim_order o ON f.order_id = o.order_id
GROUP BY o.order_dow, o.order_hour_of_day
ORDER BY o.order_dow, o.order_hour_of_day;
```

**Model Support**:
* `dim_order` provides temporal attributes (day, hour)
* `fact_order_product` provides order-level transactions

---

### BQ3: Which products have the highest reorder behavior?

```sql
SELECT 
  p.product_name,
  COUNT(*) AS total_purchases,
  SUM(CAST(f.reordered AS INT)) AS reorder_count,
  ROUND(SUM(CAST(f.reordered AS INT)) * 100.0 / COUNT(*), 2) AS reorder_rate_pct
FROM fact_order_product f
JOIN dim_product p ON f.product_id = p.product_id
GROUP BY p.product_name
HAVING COUNT(*) >= 100
ORDER BY reorder_rate_pct DESC;
```

**Model Support**:
* `reordered` measure directly supports reorder rate calculation
* `dim_product` provides product context

---

### BQ4: What are the most common product pairs?

```sql
SELECT 
  p1.product_name AS product_1,
  p2.product_name AS product_2,
  COUNT(DISTINCT f1.order_id) AS orders_with_both
FROM fact_order_product f1
JOIN fact_order_product f2 ON f1.order_id = f2.order_id
  AND f1.product_id < f2.product_id
JOIN dim_product p1 ON f1.product_id = p1.product_id
JOIN dim_product p2 ON f2.product_id = p2.product_id
GROUP BY p1.product_name, p2.product_name
HAVING COUNT(DISTINCT f1.order_id) >= 100
ORDER BY orders_with_both DESC;
```

**Model Support**:
* Order line item grain enables self-join on `order_id`
* `dim_product` provides product names for both items

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

4. **Customer Dimension**
   * Add dedicated customer dimension with behavioral metrics
   * Current: Customer attributes embedded in dim_order

5. **Additional Measures**
   * Product price, order total, discount amount (if source data becomes available)
   * Current: Only count-based metrics (orders, reorders)

6. **Conformed Dimensions**
   * If additional fact tables are added (e.g., inventory, promotions)
   * Share `dim_product`, `dim_order` across facts

---

## 10. Model Validation Checklist

✅ **Fact table grain is clearly defined**: One row per product per order  
✅ **Primary keys are unique**: All dimension PKs have no duplicates  
✅ **Foreign keys are valid**: All fact FKs have matching dimension records  
✅ **Measures are additive or semi-additive**: `reordered` additive, `add_to_cart_order` semi-additive  
✅ **Dimensions are denormalized**: Product hierarchy flattened into dim_product  
✅ **Business-friendly attributes**: Product hierarchies, temporal dimensions  
✅ **Model answers all business questions**: BQ1-BQ4 fully supported  
✅ **Performance optimized**: Simplified 3-table star schema  
✅ **Documented and validated**: All tables documented with row counts and data quality checks  

---

**Last Updated**: September 2, 2026  
**Document Owner**: Tina (Cristina)  
**Project**: Engineer Instacart
