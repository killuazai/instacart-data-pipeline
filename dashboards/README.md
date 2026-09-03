# Instacart Business Insights Dashboard 

A Databricks Lakeview dashboard answering the assignment's four business questions from the Instacart order data. Reads from the `workspace.instacart_analytics` layer — not the raw Gold fact table — so it stays fast at 33.8M\+ rows.

## Data source 

| Layer | Schema | Role |
| --- | --- | --- |
| Bronze | `workspace.instacart_bronze` | Raw CSV ingestion |
| Silver | `workspace.instacart_silver` | Cleaned, conformed tables |
| Gold | `workspace.instacart_gold` | Star schema — `gold_fact_order_product`, `gold_dim_product`, `gold_dim_order` |
| Analytics | `workspace.instacart_analytics` | **What this dashboard reads.** Pre\-aggregated answer tables, one set per business question, built by the analytics notebook |

The dashboard never queries Gold directly — every widget's dataset points at a small `analytics_*` table so the dashboard loads quickly regardless of fact\-table size.

## Dashboard structure 

| Section | Business question | Dataset(s) | Visualization |
| --- | --- | --- | --- |
| KPI row | Headline numbers | `analytics_kpis`, `analytics_top_departments` | Counters (Total Orders, Total Order Lines, Total Products, Overall Reorder Rate, Top Department) |
| Most Purchased Departments | Q1 | `analytics_top_departments` | Horizontal bar chart |
| Most Purchased Products | Q1 | `analytics_top_products` | Horizontal bar chart |
| Customer Behavior per Day/Hour | Q2 | `analytics_day_hour_patterns` | Heatmap |
| Average Basket Size per Day | Q2 (companion metric) | `analytics_basket_size_by_day` | Line chart |
| Reorder Rate | Q3 | `analytics_reorder_rates` | Horizontal bar chart \+ table (min. 500 order\-lines to qualify) |
| Which Products Are Bought Together | Q4 — team's question | `analytics_product_pairs` | Table |

The dashboard has no interactive filters — every visualization shows its full result set.

## Key insights 

- **Produce dominates**, with roughly double the order\-line volume of the next department (Dairy & Eggs). Banana is the single most purchased product platform\-wide.
- **Sunday is both the busiest day and the biggest\-basket day** — order volume peaks Sunday/Monday between \~9am–4pm, and average basket size peaks Sunday (\~11.2 items) after dipping midweek (\~9.3–9.5 items Tue–Thu). Reads as a weekly stock\-up pattern, with midweek orders being smaller top\-ups.
- **Reorder loyalty and purchase volume aren't the same thing.** The highest reorder rates (roughly 80%\+) belong almost entirely to milk/dairy products, not the top\-volume produce items — Banana is the one product that's both top\-volume and top\-reorder.
- **Bananas anchor the basket**, not just individual sales: they appear in nearly every top co\-purchased pair (with avocado, strawberries, spinach, lemon), reinforcing produce as a cluster customers buy together, not just individually.

## How to refresh 

1. Confirm `workspace.instacart_gold` is current (re\-run Bronze → Silver → Gold if source data changed).
2. Run the analytics notebook top to bottom to rebuild every `analytics_*` table, including `analytics_kpis`.
3. Open this dashboard in Databricks, refresh its datasets, and click **Publish** — draft changes aren't visible to viewers until published.

## Design notes / known limitations

- `analytics_top_products` and `analytics_reorder_rates` rank products **platform\-wide**, not per department. A future enhancement could rebuild these as per\-department Top\-N tables to support a department drill\-down.
- `analytics_product_pairs` restricts its self\-join to the 200 most\-purchased products before pairing, to keep the query performant at fact\-table scale.
- `analytics_reorder_rates` requires at least 500 order\-lines per product before it qualifies, so low\-volume products can't dominate the ranking on a small sample.
