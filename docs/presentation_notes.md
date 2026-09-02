# Presentation Notes — 5 Minutes

**Instacart Data Engineering Pipeline**

---

## 🎯 What to Open Before Starting

- [ ] This file (presentation_notes.md)
- [ ] `presentation_demo` notebook (pre-run all 8 cells)
- [ ] GitHub repository (commits page)
- [ ] `docs/` folder (show documentation files)

---

## ⏱️ MINUTE 1: PIPELINE (0:00-1:00)

### Say:
"We built a medallion architecture pipeline that ingests 6 CSV files with 33.8 million rows."

### Show:
```
CSV (6 files) → BRONZE → SILVER → GOLD → DASHBOARD
                 ↓validate ↓validate ↓validate
```

**Key Point:** Validation at every layer before moving downstream.

---

## ⏱️ MINUTE 2: MODEL (1:00-2:00)

### Say:
"Star schema with atomic grain: one row per product per order."

### Show:
```
     dim_products (49K)
            |
            ↓
    fact_order_items (33.8M)
         ↑         ↑
         |         |
dim_orders (3.3M)  dim_customers (206K)
```

**Key Point:** This grain supports all business questions—product analysis, temporal patterns, reorder behavior, and market basket analysis.

---

## ⏱️ MINUTE 3: VALIDATION (2:00-3:00)

### Say:
"We have 49 automated validation checks."

### Run (from presentation_demo notebook):
1. **Cell 1**: Row count reconciliation → 33.8M preserved ✓
2. **Cell 2**: Referential integrity → 0 orphans ✓
3. **Cell 3**: Dimension uniqueness → All PASS ✓

**Key Point:** Automated validation ensures data quality.

---

## ⏱️ MINUTE 4: DOCUMENTATION & GIT (3:00-4:00)

### Say:
"Complete documentation so another engineer can take over tomorrow."

### Show (docs/ folder):
1. README.md — How to run
2. architecture.md — Medallion design
3. data_model.md — Star schema (full spec)
4. data_dictionary.md — All columns
5. validation.md — 49 checks
6. decisions.md — Why star schema, grain choices

### Show (GitHub):
- Meaningful commit messages
- Team contributions
- Branch strategy

**Key Point:** Production-ready and maintainable.

---

## 📊 DASHBOARD STORY (Reference for Minute 5)

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

## ⏱️ MINUTE 5: BUSINESS QUESTIONS (4:00-5:00)

### Run (from presentation_demo notebook):

**Cell 4 — BQ1: Top Products**
- Bananas, strawberries, spinach
- Reorder rates: 70-85%

**Cell 5 — BQ2: Peak Times**
- Sunday mornings (10-11 AM)
- Lowest: Weekday nights

**Cell 6 — BQ3: Reorder Behavior**
- Water, milk, eggs: 85%+ reorder rate
- Essential staples

**Cell 7 — BQ4: Product Pairs**
- Bananas + strawberries
- Milk + eggs
- Complementary items (Market Basket Analysis)

**Cell 8 — Summary Stats**
- 49,687 products
- 206,209 customers
- 33.8M order items

**Key Point:** Star schema makes queries fast and business-friendly.

---

## 🎬 CLOSING

"In summary: Production-ready medallion pipeline, validated star schema with 33.8M fact rows, complete documentation, Git collaboration, and actionable business insights. Thank you!"

---

## 💡 Tips

1. **Don't read code** — show results
2. **Practice timing** — 1 min per section
3. **Have backup screenshots** — in case queries are slow
4. **Emphasize engineering** — validation, docs, maintainability
5. **Show confidence!**

---

## ❓ Anticipated Questions

**Q: Why star schema vs snowflake?**
A: Performance + simplicity. Product hierarchy is stable.

**Q: How handle late data?**
A: Currently batch. Production would use MERGE + watermarking.

**Q: Orchestration?**
A: Manual sequence now. Production: Databricks Jobs/DLT.

**Q: Runtime?**
A: Bronze ~2 min, Silver ~5 min, Gold ~8 min. Total ~15 min for 33M rows.

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
