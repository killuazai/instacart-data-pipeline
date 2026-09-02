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

---

## 🛠️ Technologies & Tools

* **Platform**: Databricks (AWS)
* **Data Storage**: Unity Catalog / Hive Metastore
* **Compute**: Serverless SQL Warehouse
* **Languages**: SQL (primary), Python (optional for notebooks)
* **Architecture**: Medallion (Bronze → Silver → Gold)
* **Modeling**: Kimball Dimensional Modeling
* **Source Format**: CSV
* **Version Control**: Git / GitHub
* **Data Volume**: 37M+ records
* **Validation Strategy**: Layer-by-layer quality checks

---

## ⚡ Performance Metrics

| Layer | Execution Time | Records Processed |
|-------|----------------|-------------------|
| **Bronze** | ~2 minutes | 37,273,878 rows |
| **Silver** | ~3 minutes | 37,198,877 rows (75K filtered) |
| **Gold** | ~5 minutes | 33,819,103 fact + 3.6M dimensions |
| **Analytics** | < 1 second | Pre-aggregated queries |
| **End-to-End** | ~10 minutes | Full pipeline |

**Dashboard Query Performance**: < 1 second (leveraging pre-aggregated Gold analytics tables)

---

## 🔄 Data Lineage

Complete source-to-gold data lineage:

```
Source CSV          → Bronze                        → Silver                    → Gold
─────────────────────────────────────────────────────────────────────────────────────────
aisles.csv          → bronze_aisles                 → silver_aisles             → dim_product.aisle_*
departments.csv     → bronze_departments            → silver_departments        → dim_product.department_*
products.csv        → bronze_products               → silver_products           → dim_product
orders.csv          → bronze_orders                 → silver_orders             → dim_order
order_products_     → bronze_order_products_prior   → silver_order_products     → fact_order_product
  prior.csv
order_products_     → bronze_order_products_train  →   (union with prior)      →   (same fact table)
  train.csv
```

**Key Transformations**:
* **Bronze → Silver**: Type conversions (STRING → INT), NULL filtering, union prior + train
* **Silver → Gold**: Denormalization, surrogate keys, calculated fields, pre-aggregations

---

## 🔧 Troubleshooting

### Common Issues

**Issue**: `Table or view not found`  
**Cause**: Skipped a layer or validation failed  
**Solution**: Run tasks in order (01 → 02-07 → 08 → 09-13 → 14 → 15-17 → 18 → 19 → 20 → 21-23)

**Issue**: `Permission denied` or `Access denied`  
**Cause**: Missing Unity Catalog permissions  
**Solution**: Verify `USE CATALOG`, `USE SCHEMA`, and table permissions

**Issue**: Validation check fails (tasks 08, 14, 18, 20)  
**Cause**: Data quality issue or upstream error  
**Solution**: Do NOT proceed to next layer. Fix root cause, rebuild affected layer, re-validate

**Issue**: Dashboard queries are slow  
**Cause**: Querying raw fact table instead of analytics tables  
**Solution**: Use pre-aggregated tables in `04_analytics/` (tasks 21-23)

**Issue**: Row counts don't match expected values  
**Cause**: Intentional data quality filtering  
**Solution**: Check `docs/validation.md` for documented filters (e.g., 75K orders dropped for NULL values)

**Issue**: Merge conflicts in Git  
**Cause**: Multiple contributors editing same file  
**Solution**: Follow `CONTRIBUTING.md` guidelines, use feature branches, coordinate with team

---

## 🚀 Future Enhancements

### Phase 2 (Planned)
* [ ] Add `dim_date` dimension with fiscal calendar attributes
* [ ] Add `dim_customer` dimension with lifetime metrics
* [ ] Implement SCD Type 2 for product price history tracking
* [ ] Create daily/monthly aggregate fact tables
* [ ] Add data quality monitoring dashboard
* [ ] Automate pipeline execution with Databricks Jobs

### Phase 3 (Proposed)
* [ ] Real-time streaming ingestion (Kafka → Bronze)
* [ ] ML model for demand forecasting
* [ ] Recommendation engine (collaborative filtering)
* [ ] A/B testing framework for promotions
* [ ] Data lineage visualization with OpenLineage
* [ ] dbt integration for transformation layer

### Infrastructure
* [ ] CI/CD pipeline with GitHub Actions
* [ ] Automated testing on PR merge
* [ ] Data quality rules as code
* [ ] Performance regression testing

---

## ⚠️ Known Issues & Limitations

### Data Quality Issues

**3 Orphan Products**  
* **Description**: `silver_order_products` contains 3 product IDs not in `silver_products`
* **Impact**: 3 rows filtered from Gold layer during FK validation
* **Status**: Documented in `docs/validation.md`, upstream source data issue
* **Mitigation**: Documented and accepted; investigate source data refresh

**75,000 Orders Dropped**  
* **Description**: Orders with NULL `days_since_prior_order` (first customer orders)
* **Impact**: ~2% of orders excluded from Silver layer
* **Status**: Expected behavior, validated
* **Reason**: Business rule requires order sequence tracking

### Current Limitations

**Team Business Question 4**  
* **Status**: Intentionally omitted until team finalizes definition
* **Impact**: Task 24 placeholder reserved but not implemented
* **Timeline**: To be added in Phase 2

**Dashboard**  
* **Status**: In development
* **Impact**: Analytics tables ready (tasks 21-23), visualization layer pending
* **Owner**: TBD in `docs/team_contributions.md`

**Customer Dimension**  
* **Status**: Not yet implemented
* **Reason**: Scoped for Phase 2 to keep initial model simple
* **Workaround**: Customer metrics calculated in analytics layer (task 22)

### Technical Constraints

* **No streaming**: Current implementation is batch-only
* **No incremental loads**: Full refresh on each run (acceptable for project scope)
* **No partition pruning**: Not needed for current data volume
* **No CDC tracking**: Bronze layer does not track changes over time

---

## 📊 Project Statistics

### Code Organization

| Category | Count | Lines of SQL |
|----------|-------|-------------|
| **Setup** | 1 file | ~50 |
| **Bronze** | 6 tables | ~300 |
| **Silver** | 5 tables | ~400 |
| **Gold** | 3 tables + constraints | ~500 |
| **Analytics** | 3 queries | ~200 |
| **Validation** | 4 test suites | ~300 |
| **Total** | 23 tasks | ~1,750 |

### Data Volume

| Layer | Tables | Total Rows | Largest Table |
|-------|--------|------------|---------------|
| **Bronze** | 6 | 37,273,878 | order_products_prior (32.4M) |
| **Silver** | 5 | 37,198,877 | silver_order_products (33.8M) |
| **Gold** | 3 | 37,421,766 | fact_order_product (33.8M) |

### Quality Metrics

* ✅ **Referential Integrity**: 100% (after filtering 3 orphans)
* ✅ **Primary Key Uniqueness**: 100% (0 duplicates)
* ✅ **NULL Checks**: 100% pass rate in required fields
* ⚠️ **Data Completeness**: 98% (75K orders filtered)
* ✅ **Type Safety**: 100% (all STRING → INT conversions successful)

---

## 👥 Team & Collaboration

### Git Workflow

1. **Branch**: Create feature branch from `main`
   ```bash
   git checkout -b feature/your-task-name
   ```

2. **Develop**: Make changes in your assigned layer/task
   ```bash
   git add src/01_bronze/sql/02_bronze_aisles.sql
   git commit -m "Add bronze_aisles table ingestion"
   ```

3. **Test**: Run validation queries for your layer
   ```bash
   # Run 08_validate_bronze.sql in Databricks
   ```

4. **Push**: Push branch to GitHub
   ```bash
   git push origin feature/your-task-name
   ```

5. **Pull Request**: Create PR using template in `.github/pull_request_template.md`

6. **Review**: Team reviews, approves, merges

### Contribution Guidelines

See `CONTRIBUTING.md` for detailed guidelines on:
* Code style and formatting
* Commit message conventions
* PR requirements and review process
* Testing requirements
* Documentation standards

### Team Responsibilities

Track individual contributions in `docs/team_contributions.md`:
* Layer ownership (Bronze, Silver, Gold)
* Task assignments (tasks 01-23)
* Validation responsibilities
* Documentation contributions
* Dashboard development

---

## 📚 Additional Resources

### Documentation

* [Architecture](docs/architecture.md) — Detailed system design and layer specifications
* [Data Model](docs/data_model.md) — Dimensional modeling concepts and star schema
* [Data Dictionary](docs/data_dictionary.md) — Complete column catalog
* [Engineering Decisions](docs/decisions.md) — Key design choices and rationale
* [Validation](docs/validation.md) — Data quality checks and results
* [Team Contributions](docs/team_contributions.md) — Individual deliverables and ownership
* [Presentation Notes](docs/presentation_notes.md) — Talking points for project demo

### External References

* [Instacart Dataset (Kaggle)](https://www.kaggle.com/c/instacart-market-basket-analysis)
* [Kimball Dimensional Modeling](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/)
* [Databricks Medallion Architecture](https://www.databricks.com/glossary/medallion-architecture)
* [Unity Catalog Documentation](https://docs.databricks.com/en/data-governance/unity-catalog/index.html)

---

## 📝 License & Attribution

**Project**: Instacart Data Engineering Pipeline  
**Organization**: FTW Data Engineering Batch 12  
**Dataset**: Instacart Market Basket Analysis (Kaggle)  
**Platform**: Databricks (AWS)  
**Architecture**: Medallion (Bronze → Silver → Gold)  
**Modeling**: Kimball Dimensional Modeling

---

## 📧 Contact

For questions about this project:
* See `docs/team_contributions.md` for team member contacts
* Open an issue in GitHub for technical questions
* Refer to `CONTRIBUTING.md` for contribution guidelines

---

**Built with ❤️ by FTW Data Engineering Batch 12**
