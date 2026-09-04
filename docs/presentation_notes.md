# Presentation Notes — 5 Minutes

**Instacart Data Engineering Pipeline**

---

## 🎯 PRESENTATION ASSIGNMENTS

**👤 TINA:**
* Bronze → Silver → Gold pipeline flow
* Validation (all 3 layers)
* Dashboard Q3-4 (Reorder Behavior, Product Pairs)
* Documentation Overview

**👤 MAEVE:**
* Data Model (Star Schema)
* Business Analytics/Questions intro
* Dashboard Q1-2 (Top Products, Temporal Patterns)

---

##  What to Open Before Starting

- [ ] This file (presentation_notes.md)
- [ ] GitHub repository (commits page)
- [ ] `docs/` folder (show documentation files)
- [ ] Dashboard (open in separate tab)

---

## 👤 TINA SECTION 1: PIPELINE (Bronze → Silver → Gold)

### Say:
"We built a medallion architecture pipeline that ingests 6 CSV files with 37 million source rows into 33.8 million validated fact rows."

### Show:
```
CSV (6 files, 37M rows)
    ↓
BRONZE (Raw ingestion, 6 tables)
    ↓ validate
SILVER (Cleaned & standardized, 5 tables)
    ↓ validate  
GOLD (Star schema, 1 fact + 2 dims)
    ↓ validate
DASHBOARD
```

**Key Points:**
* **Bronze**: Preserves raw data with `_rescued_data` column (0 malformed records)
* **Silver**: Fixed data types (STRING→INT), NULL filtering, added metadata
* **Gold**: Dimensional model with Unity Catalog PK/FK constraints
* **Validation at every layer** before moving downstream

**Stats:**
* 75,000 orders dropped in Silver (NULL filtering — documented)
* 1 product dropped (NULL validation)
* 3 orphan products filtered before Gold FK constraint
* Final: 33.8M fact rows, 0 orphans, 100% referential integrity

---

## 👤 TINA SECTION 2: VALIDATION

### Say:
"We have comprehensive automated validation at every layer—Bronze checks row counts and primary keys, Silver validates referential integrity, and Gold enforces Unity Catalog constraints."

### Run (from presentation_demo notebook):
1. **Cell 1**: Bronze row count reconciliation → 37M source = 37M Bronze ✓
2. **Cell 2**: Silver referential integrity → 0 NULL keys ✓  
3. **Cell 3**: Gold constraint validation → 0 orphans, all PASS ✓

**Key Validation Checks:**

**Bronze (Query 08):**
* Row counts match expected (hardcoded)
* 0 NULL required IDs
* 0 duplicate primary keys
* 0 rescued/malformed rows
* Status: PASS/FAIL with `assert_true` (stops pipeline on failure)

**Silver:**
* Bronze → Silver row reconciliation (document intentional drops)
* 0 NULL foreign keys
* Valid ranges (order_hour: 0-23, order_dow: 0-6, reordered: 0 or 1)
* Valid `eval_set` values ('prior' or 'train')
* FK integrity (identified 3 orphan products)

**Gold:**
* Silver → Gold reconciliation (33.8M - 3 orphans = 33.8M)
* Fact-to-dimension FK validation (0 orphans)
* Composite PK uniqueness (order_id, add_to_cart_order)
* Unity Catalog constraints enforced

**Key Point:** Automated validation caught data quality issues early—75K invalid orders, 3 orphan products—before they reached Gold.

---

## 👤 MAEVE SECTION 1: DATA MODEL (Star Schema)

### Say:
"Our star schema has atomic grain: one row represents one product in one order. This supports all business questions from a single fact table."

### Show:
```
     dim_product (49,687 products)
     - product_id (PK)
     - product_name
     - aisle_name, department_name
     - product_hierarchy
            |
            ↓ FK
    fact_order_product (33.8M line items)
     - order_id, add_to_cart_order (Composite PK)
     - product_id (FK)
     - reordered (measure)
         ↑ FK
         |
    dim_order (3.3M orders)
     - order_id (PK)
     - user_id, order_number
     - order_dow, order_hour_of_day
     - day_of_week_name, time_of_day_bucket
     - days_since_prior_order
```

**Key Design Decisions:**

1. **Atomic Grain**: One row = one product in one order (order line item)
   * Supports product analysis, temporal patterns, reorder behavior, basket analysis
   * No need for separate aggregated tables

2. **Composite Natural Key**: (order_id, add_to_cart_order)
   * Preserves business meaning
   * `add_to_cart_order` serves dual purpose: PK component + measure (cart sequence)

3. **No Separate Customer Dimension**: 
   * Customer attributes embedded in dim_order (user_id, order_number)
   * Simplifies queries (fact → order vs fact → order → customer)
   * Customer metrics derived via aggregation

4. **Denormalized Product Hierarchy**:
   * department → aisle → product in single dimension
   * `product_hierarchy` column: "produce / fresh fruits / Banana"
   * Fast queries, no multi-hop joins

5. **Unity Catalog PK/FK Constraints**:
   * Declarative enforcement (prevents orphans at write time)
   * Self-documenting relationships
   * Optimizer can leverage constraints

**Stats:**
* 33.8M fact rows
* 3.3M orders, 206K customers
* 49.7K products (21 depts, 134 aisles)
* ~10.1 items/order
* 59% overall reorder rate

---

## 👤 MAEVE SECTION 2: BUSINESS QUESTIONS (Intro)

### Say:
"The star schema enables us to answer four key business questions about purchasing behavior, and all the queries run in under 1 second."

**Four Business Questions:**

1. **Q1: Which products and departments are purchased most frequently?**
   * Identifies top-volume products and categories
   * Supports assortment optimization and inventory planning

2. **Q2: How does purchasing behavior change by day of week and hour?**
   * Reveals temporal patterns for staffing and fulfillment
   * Shows basket size variation across time

3. **Q3: Which products have the highest reorder behavior?**
   * Measures customer loyalty per product
   * Identifies habitual purchases vs one-time buys

4. **Q4: What are the most common product pairs bought together?**
   * Market basket analysis for cross-sell opportunities
   * Reveals complementary purchase patterns

---

## 📊 DASHBOARD STORY (Reference for Q1-Q4)

**Headline numbers**
3.35M orders, 33.82M order lines, 49.69K products, a 59% overall reorder rate. That reorder rate alone is worth calling out up front — nearly 6 in 10 items purchased are repeats, which tells you this is a replenishment-driven grocery habit, not one-off shopping.

**Q1 — Most purchased products and departments**
Produce dominates, by a wide margin. It's roughly double the order-line volume of the #2 department (Dairy & Eggs), and together Produce, Dairy & Eggs, and Snacks make up the clear top tier — everything below Beverages trails off fast.
At the product level, this shows up directly: Banana is the single most purchased item (~500K orders), well ahead of Bag of Organic Bananas (~400K), with the rest of the top 15 almost entirely organic produce (strawberries, spinach, avocado, lemon, limes). Takeaway: Instacart's volume is anchored by a small set of fresh-produce staples, not spread evenly across the catalog.

**Q2 — Behavior by day of week and hour**
Two patterns stack on top of each other here:

* When people order: the heatmap shows almost no activity overnight (0–6 hours), a build from ~7am, and a sustained peak roughly 9am–4pm, heaviest on Sunday and Monday.
* How much they order: average basket size dips midweek (~9.3–9.5 items on Tue/Wed/Thu) and climbs toward the weekend, peaking Sunday at ~11.2 items/order.
Takeaway: Sunday isn't just the busiest day, it's also the biggest-basket day — that's consistent with a weekly stock-up shop, while the midweek orders are smaller top-up trips. That's a genuinely useful staffing/inventory insight: Sunday needs both more orders fulfilled and more items per order handled.

**Q3 — Highest reorder behavior**
This list looks completely different from the top-purchased list — it's dominated by milk and dairy variants (Half and Half, Organic Omega-3 Milk, Lactose-Free Whole Milk, Goat Milk, etc.), nearly all sitting in a tight, consistently high band (roughly 80%+ reorder rate). Banana is the one crossover item that's both a top-volume and top-reorder product.
Takeaway: milk is the most habitual purchase on the platform. A customer who buys a specific milk type buys that exact one again and again — even though individual milk SKUs have far lower order counts than bananas (compare Organic Reduced Fat Milk's 36,869 orders to Banana's 491,291), the loyalty per product is higher. That's a distinct insight from Q1: high volume and high reorder rate are answering two different business questions, and dairy vs. produce is the clearest example of that split in your own data.

**Q4 — Products bought together**
Banana (or Bag of Organic Bananas) appears in almost every top pair — with Hass Avocado (64,761 co-occurrences), Organic Strawberries (64,702), Baby Spinach (52,608), and Large Lemon (43,038). This is the produce-department dominance from Q1 showing up again at the basket level: it's not just that produce items are individually popular, they're bought together as a cluster — bananas anchor a recurring "produce basket" alongside berries, avocado, and greens.

**Putting it together**
The four questions reinforce one connected story: Produce (and specifically Banana) is both the volume driver and the co-purchase anchor of the platform, dairy is where loyalty/reorder behavior is strongest, and Sunday is when both order volume and basket size peak. That's a clean narrative arc for your 5-minute presentation — volume (Q1) → timing (Q2) → loyalty (Q3) → basket composition (Q4), all pointing back to the same handful of categories from different angles.

---

## 👤 MAEVE: DASHBOARD Q1-Q2

### Q1: Top Products & Departments

**Run Cell 4 from presentation_demo**

**Key Findings:**
* **Produce dominates**: ~2x the volume of #2 department (Dairy & Eggs)
* **Top 3**: Produce, Dairy & Eggs, Snacks make up the top tier
* **#1 Product**: Banana (~500K orders) — well ahead of #2 Organic Bananas (~400K)
* **Top 15**: Almost entirely organic produce (strawberries, spinach, avocado, lemon, limes)

**Insight:** Instacart's volume is anchored by a small set of fresh-produce staples, not spread evenly across the catalog.

---

### Q2: Temporal Patterns (Day & Hour)

**Run Cell 5 from presentation_demo**

**Key Findings:**

**When people order (heatmap):**
* Almost no activity overnight (0-6am)
* Build from ~7am, sustained peak 9am-4pm
* Heaviest on Sunday and Monday

**How much they order (basket size):**
* Dips midweek (~9.3-9.5 items on Tue/Wed/Thu)
* Climbs toward weekend
* **Peaks Sunday at ~11.2 items/order**

**Insight:** Sunday isn't just the busiest day, it's also the biggest-basket day — consistent with a weekly stock-up shop. Midweek orders are smaller top-up trips. **Staffing/inventory implication**: Sunday needs both more orders fulfilled AND more items per order handled.

---

## 👤 TINA: DASHBOARD Q3-Q4

### Q3: Highest Reorder Behavior

**Run Cell 6 from presentation_demo**

**Key Findings:**
* **List looks completely different from Q1** (top-purchased)
* **Dominated by milk & dairy variants**: Half and Half, Organic Omega-3 Milk, Lactose-Free Whole Milk, Goat Milk
* **All sitting in tight band: 80%+ reorder rate**
* **Banana is the one crossover**: Both top-volume AND top-reorder

**Insight:** Milk is the most **habitual purchase** on the platform. A customer who buys a specific milk type buys that exact one again and again. Even though individual milk SKUs have far lower order counts than bananas (compare Organic Reduced Fat Milk's 36,869 orders vs Banana's 491,291), the **loyalty per product is higher**. 

**Key distinction:** High volume (Q1) and high reorder rate (Q3) answer two different business questions — **dairy vs produce** is the clearest example of that split.

---

### Q4: Products Bought Together (Market Basket)

**Run Cell 7 from presentation_demo**

**Key Findings:**
* **Banana appears in almost every top pair**:
  * Banana + Hass Avocado (64,761 co-occurrences)
  * Banana + Organic Strawberries (64,702)
  * Banana + Baby Spinach (52,608)
  * Banana + Large Lemon (43,038)

**Insight:** This is the **produce-department dominance from Q1 showing up again at the basket level**. It's not just that produce items are individually popular — they're bought together as a cluster. Bananas anchor a recurring "produce basket" alongside berries, avocado, and greens.

---

**Connecting the Story (Q1 → Q2 → Q3 → Q4):**

* **Q1 (Volume)**: Produce (Banana) is the volume driver
* **Q2 (Timing)**: Sunday is when both order volume AND basket size peak
* **Q3 (Loyalty)**: Dairy is where reorder behavior is strongest
* **Q4 (Basket)**: Banana is the co-purchase anchor of the platform

**Summary**: All four questions point back to the same handful of categories from different angles — volume, timing, loyalty, and basket composition.

---

## 👤 TINA: DOCUMENTATION OVERVIEW

### Say:
"Complete documentation so another engineer can take over tomorrow. Everything is in the docs folder."

### Show (docs/ folder):

1. **README.md** — How to run the pipeline
2. **architecture.md** — Medallion design (Bronze → Silver → Gold)
3. **data_model.md** — Star schema specification (fact + dimensions, grain, constraints)
4. **data_dictionary.md** — All columns across all layers (Bronze, Silver, Gold)
5. **validation.md** — All validation checks (Bronze, Silver, Gold)
6. **decisions.md** — Engineering decisions (why star schema, why composite PK, why no dim_customer)
7. **team_contributions.md** — Who built what (Nadine, Ina, Cath, Maeve, Angela, Tina)

### Show (GitHub):
* Meaningful commit messages
* Team collaboration (6 contributors)
* Branch strategy

**Key Point:** Production-ready and maintainable — another engineer can understand the pipeline, run it, and extend it.

---

## 🎬 CLOSING

"In summary: Production-ready medallion pipeline, validated star schema with 33.8M fact rows, complete documentation, Git collaboration, and actionable business insights. Thank you!"

---

## 💡 Tips

1. **Don't read code** — show results
2. **Stick to your sections** — Tina: pipeline/validation/Q3-Q4/docs, Maeve: model/Q1-Q2
3. **Practice timing** — rehearse your sections
4. **Have backup screenshots** — in case queries are slow
5. **Emphasize engineering** — validation, docs, maintainability, Unity Catalog constraints
6. **Hand off smoothly** — "Maeve will now show the star schema design..."
7. **Show confidence!**

---

## ❓ Anticipated Questions

**Q: Tomorrow, 5,000 new orders arrive. What happens? Can you explain INGEST → TRANSFORM → VALIDATE → MODEL → SERVE without rebuilding everything manually?**

A: **Bronze does not intentionally discard records. Its loaded counts must match the approved snapshot counts, so row_difference = 0 is required.**

**The validation rule:**
* Bronze preserves **all source data** — no filtering, no transformations
* Expected counts are **hardcoded** in the validation query (not dynamically read from source)
* These counts come from the **approved snapshot** (the baseline we validated)
* Any row difference (positive or negative) indicates a data quality issue:
  * **row_difference < 0**: Missing rows (failed ingestion, corrupted source file)
  * **row_difference > 0**: Extra rows (duplicate ingestion, wrong source file)
* Both scenarios require investigation before moving to Silver

**For an approved new snapshot or stress test:**
1. Update `expected_rows` in the validation query for each affected table
2. Update the count subtracted in `row_difference` calculation
3. Rerun Bronze validation to confirm exact match (row_difference = 0)
4. This is a **controlled update**, not a blind acceptance of new data

**Do NOT change the rule to >= 0** — that would also accept unintended extra rows.

**Example (from Query 08 — Bronze Validation):**
```sql
-- For bronze_orders
SELECT 
  'bronze_orders' AS table_name,
  3421083 AS expected_rows,  -- Hardcoded approved count
  COUNT(*) AS actual_rows,
  (COUNT(*) - 3421083) AS row_difference,  -- Must = 0 for PASS
  ...
FROM bronze_orders
```

**For the 5,000 new orders scenario:**
* Update hardcoded expected counts to new baseline: `3421083 + 5000 = 3426083`
* Update row_difference calculation: `(COUNT(*) - 3426083)`
* Rerun validation → confirms exact match → PASS
* Then proceed: Bronze → Silver → Gold

**Key Point:** Bronze validation is **strict by design** — it stops the pipeline on any unexpected data change, ensuring Silver only processes known-good data.

---

**Q: Follow-up — How does the rest of the pipeline handle the new data once Bronze passes validation?**

A: **The entire pipeline is declarative SQL — just rerun the notebooks in sequence.**

**How it works (INGEST → TRANSFORM → VALIDATE → MODEL → SERVE):**

1. **INGEST** (Bronze): `CREATE OR REPLACE TABLE` runs again → Auto Loader `read_files()` ingests new CSVs
2. **TRANSFORM** (Silver): `CREATE OR REPLACE TABLE` rebuilds → type conversions, NULL filtering, UNION logic all reapply
3. **VALIDATE**: Same validation queries run automatically → checks row counts, NULL keys, FK integrity, domain rules
4. **MODEL** (Gold): `CREATE OR REPLACE TABLE` rebuilds star schema → FK constraints enforce referential integrity, orphans filtered
5. **SERVE** (Dashboard): Dashboard queries hit Gold tables → updated results immediately (< 1 second)

**What makes it repeatable:**
* Automated validation at every layer
* Idempotent SQL (`CREATE OR REPLACE`)
* FK constraints prevent bad data from reaching Gold
* Documentation ensures another engineer can run it

**What makes it traceable:**
* `loaded_at` timestamps track when data entered each layer
* `source_system` column preserves lineage (prior vs train)
* Git history shows all changes
* Validation logs show pass/fail per layer

**Production enhancement:** Orchestrate with Databricks Jobs (scheduled) or Delta Live Tables (continuous) for full automation

---

**Q: Why star schema vs snowflake?**
A: Performance + simplicity. Product hierarchy is stable.

**Q: How handle late data?**
A: Currently batch. Production would use MERGE + watermarking.

**Q: Orchestration?**
A: Manual sequence now. Production: Databricks Jobs/DLT.

**Q: Runtime?**
A: Bronze ~2 min, Silver ~5 min, Gold ~8 min. Total ~15 min for 37M source → 33.8M fact rows.

**Q: Biggest learning?**
A: Validation is critical. Caught issues early by validating at every layer.

---

## 📋 Final Checklist

- [ ] Pre-run all cells in `presentation_demo` notebook
- [ ] Test GitHub access
- [ ] Time yourself (practice = 5 min)
- [ ] Prepare for questions
- [ ] Have backup screenshots ready

**Good luck! 🎉**
