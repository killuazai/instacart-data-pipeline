# Instacart Data Engineering Pipeline

## Project Overview

This repository contains the group implementation of the FTW Batch 12 Instacart Data Engineering homework.

Required flow:

`INSTACART -> BRONZE -> SILVER -> GOLD -> DASHBOARD`

The SQL filenames follow the team's approved Databricks saved-query naming convention so all contributors use the same task names.

## Assignment Deliverables

The repository should provide evidence of:

- Pipeline: Bronze -> Silver -> Gold
- Dimensional model: facts, dimensions, grain, keys, relationships
- Validation: evidence that the data is correct
- Documentation: README, architecture, model, data dictionary, decisions
- Git: meaningful contributions from the team
- Dashboard: useful output from Gold

## Business Questions

1. Which products and departments are purchased most frequently?
2. How does customer purchasing behavior change by day of week and hour of day?
3. Which products have the highest reorder behavior?
4. Team question: intentionally not included yet

## Repository Structure

```text
instacart-data-pipeline/
├── README.md
├── CONTRIBUTING.md
├── .gitignore
├── .github/
│   └── pull_request_template.md
├── docs/
│   ├── architecture.md
│   ├── data_model.md
│   ├── data_dictionary.md
│   ├── decisions.md
│   ├── validation.md
│   ├── team_contributions.md
│   ├── presentation_notes.md
│   └── diagrams/
├── src/
│   ├── 00_setup/
│   │   └── 01_setup.sql
│   ├── 01_bronze/sql/
│   │   ├── 02_bronze_aisles.sql
│   │   ├── 03_bronze_departments.sql
│   │   ├── 04_bronze_products.sql
│   │   ├── 05_bronze_orders.sql
│   │   ├── 06_bronze_order_products_prior.sql
│   │   └── 07_bronze_order_products_train.sql
│   ├── 02_silver/sql/
│   │   ├── 09_silver_aisles.sql
│   │   ├── 10_silver_departments.sql
│   │   ├── 11_silver_products.sql
│   │   ├── 12_silver_orders.sql
│   │   └── 13_silver_order_products.sql
│   ├── 03_gold/sql/
│   │   ├── 15_gold_dim_product.sql
│   │   ├── 16_gold_dim_order.sql
│   │   ├── 17_gold_fact_order_product.sql
│   │   └── 19_gold_constraints.sql
│   └── 04_analytics/sql/
│       ├── 21_products_departments_frequency.sql
│       ├── 22_customer_behavior_day_hour.sql
│       └── 23_product_reorder_behavior.sql
├── tests/
│   ├── 08_validate_bronze.sql
│   ├── 14_validate_silver.sql
│   ├── 18_validate_gold_pre_constraints.sql
│   └── 20_validate_gold_final.sql
├── dashboards/
│   ├── README.md
│   └── screenshots/
└── notebooks/
    └── README.md
```

## SQL Task Naming

Use the filename stem as the Databricks saved-query name.

| Task | Saved-query / filename |
|---:|---|
| 01 | `01_setup.sql` |
| 02 | `02_bronze_aisles.sql` |
| 03 | `03_bronze_departments.sql` |
| 04 | `04_bronze_products.sql` |
| 05 | `05_bronze_orders.sql` |
| 06 | `06_bronze_order_products_prior.sql` |
| 07 | `07_bronze_order_products_train.sql` |
| 08 | `08_validate_bronze.sql` |
| 09 | `09_silver_aisles.sql` |
| 10 | `10_silver_departments.sql` |
| 11 | `11_silver_products.sql` |
| 12 | `12_silver_orders.sql` |
| 13 | `13_silver_order_products.sql` |
| 14 | `14_validate_silver.sql` |
| 15 | `15_gold_dim_product.sql` |
| 16 | `16_gold_dim_order.sql` |
| 17 | `17_gold_fact_order_product.sql` |
| 18 | `18_validate_gold_pre_constraints.sql` |
| 19 | `19_gold_constraints.sql` |
| 20 | `20_validate_gold_final.sql` |
| 21 | `21_products_departments_frequency.sql` |
| 22 | `22_customer_behavior_day_hour.sql` |
| 23 | `23_product_reorder_behavior.sql` |

The fourth team business question is intentionally omitted until the team finalizes it.

## How to Run

Run the saved queries in task-number order while respecting layer dependencies:

`01 -> 02-07 -> 08 -> 09-13 -> 14 -> 15-17 -> 18 -> 19 -> 20 -> 21-23`

Parallel tasks within the same layer may be run independently when their upstream validation has passed.

Do not continue downstream when a validation check fails. Fix the root cause, rebuild the affected layer, then validate again.

## Validation

Validation is kept in `tests/` and uses the same task numbers as the Databricks saved queries:

- `08_validate_bronze.sql`
- `14_validate_silver.sql`
- `18_validate_gold_pre_constraints.sql`
- `20_validate_gold_final.sql`

## Engineering Decisions

Record decisions that change structure, grain, joins, cleaning rules, or dashboard behavior in `docs/decisions.md`.

## Team Contributions

Each teammate should contribute through a branch and pull request. Track final ownership and merged contributions in `docs/team_contributions.md`.

## Dashboard

Add dashboard details and screenshots in `dashboards/`.
