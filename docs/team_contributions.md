# Team Contributions

**Engineer Instacart — FTW Data Engineering Batch 12**

---

## Project Team

| Team Member | Primary Role | Secondary Role |
|-------------|--------------|----------------|
| **Nadine** | Bronze Layer Engineer | Bronze Validation |
| **Ina** | Silver Layer Engineer | Silver Validation |
| **Cath** | Gold Layer Engineer | Gold Validation |
| **Maeve** | Business Analytics | Dashboard Development |
| **Angela** | GitHub Organization | Query Documentation |
| **Tina (Cristina)** | Documentation  | Star Schema Design |

---

## Detailed Contributions

### Nadine — Bronze Layer + Bronze Validation

**Primary Responsibility**: Raw data ingestion from source CSV files into Bronze layer tables

#### Deliverables

1. **Bronze Layer Implementation** (`bronze_instacart.ipynb`)
   * Ingested 6 source CSV files using Databricks `read_files()` function
   * Created 6 Bronze tables:
     * `bronze_aisles` (134 rows)
     * `bronze_departments` (21 rows)
     * `bronze_products` (49,688 rows)
     * `bronze_orders` (3,421,083 rows)
     * `bronze_order_products_prior` (32,434,489 rows)
     * `bronze_order_products_train` (1,384,617 rows)
   * Preserved source data structure with `_rescued_data` column for data quality monitoring

2. **Bronze Validation**
   * Validated `_rescued_data` column (confirmed all NULL — no malformed records)
   * Performed row count verification
   * Conducted schema inspection (DESCRIBE statements)
   * Created sample data queries for all Bronze tables
   * Documented Bronze layer statistics

#### Key Accomplishments

* ✅ Successfully ingested 37+ million source records with zero data loss
* ✅ Preserved raw data integrity for downstream processing
* ✅ Documented data quality baseline (0 malformed CSV records)
* ✅ Established Bronze layer as immutable source of truth

#### Technical Skills Demonstrated

* Databricks `read_files()` function for CSV ingestion
* SQL DDL (CREATE OR REPLACE TABLE)
* Data quality validation techniques
* Schema inspection and documentation

---

### Ina — Silver Layer + Silver Validation

**Primary Responsibility**: Data cleaning, standardization, and quality validation

#### Deliverables

1. **Silver Layer Implementation** (`silver_instacart.ipynb`)
   * Cleaned and standardized 5 Silver tables:
     * `silver_aisles` (134 rows)
     * `silver_departments` (21 rows)
     * `silver_products` (49,687 rows)
     * `silver_orders` (3,346,083 rows)
     * `silver_order_products` (33,819,106 rows — union of prior + train)
   * Performed data type corrections:
     * CAST `aisle_id` from STRING to INT
     * CAST `department_id` from STRING to INT
   * Applied data quality filters:
     * Removed NULL values in required fields
     * Preserved intentional NULLs (`days_since_prior_order`)
   * Added metadata columns:
     * `loaded_at` (ETL timestamp)
     * `source_system` (lineage tracking for union)

2. **Silver Validation**
   * **Row Count Reconciliation**: Bronze → Silver
     * Documented 75,000 orders dropped (NULL filtering)
     * Documented 1 product dropped (NULL validation)
   * **NULL Checks**: Verified 0 NULLs in required fields
   * **Primary Key Uniqueness**: Confirmed 0 duplicates in all tables
   * **Referential Integrity**: Tested foreign key relationships
     * Identified 3 orphan products (documented data quality issue)
   * **Data Type Verification**: Confirmed successful INT conversions

3. **Engineering Decisions**
   * Decided to union `bronze_order_products_prior` and `bronze_order_products_train`
   * Added `source_system` column for lineage tracking
   * Documented data quality thresholds and filtering logic

#### Key Accomplishments

* ✅ Cleaned 33.8M records with comprehensive validation
* ✅ Fixed data type issues (STRING → INT conversions)
* ✅ Achieved 100% referential integrity in most relationships
* ✅ Documented all data quality issues transparently
* ✅ Created union strategy for prior + train datasets

#### Technical Skills Demonstrated

* Data type casting and validation
* NULL handling strategies
* UNION operations
* Referential integrity testing
* Data quality reconciliation
* Metadata enrichment (loaded_at, source_system)

---

### Cath — Gold Layer + Gold Validation

**Primary Responsibility**: Dimensional modeling and business analytics table creation

#### Deliverables

1. **Dimensional Model** (`gold_instacart.ipynb`)
   * **Fact Table**: `fact_order_items` (33,819,103 rows)
     * Defined grain: One row per product per order
     * Created surrogate key (`order_item_key`)
     * Established foreign keys to all dimensions
     * Preserved measures (`add_to_cart_order`, `is_reordered`)
   
   * **Dimension Tables**:
     * `dim_products` (49,687 rows) — Denormalized product hierarchy
     * `dim_customers` (206,209 rows) — Pre-aggregated customer metrics
     * `dim_orders` (3,346,083 rows) — Temporal attributes

2. **Business Analytics Tables**
   * `gold_product_popularity` (49,684 rows)
     * Answers BQ1: Which products and departments are purchased most frequently?
     * Metrics: total_orders, unique_customers, reorder_rate_pct
   
   * `gold_temporal_patterns` (168 rows)
     * Answers BQ2: How does purchasing behavior change by day and hour?
     * Metrics: total_orders, total_items, avg_items_per_order, unique_customers
   
   * `gold_reorder_behavior` (42,987 rows)
     * Answers BQ3: Which products have the highest reorder behavior?
     * Metrics: reorder_rate_pct, reorder_rank, total_purchases
   
   * `gold_basket_pairs` (1,000 rows)
     * Answers BQ4: What are the most common product pairs?
     * Metrics: orders_with_both, customers_buying_both, pair_frequency_pct

3. **Gold Validation**
   * **Row Count Reconciliation**: Silver → Gold
   * **Fact-to-Dimension Relationships**: Verified 0 orphans in all foreign keys
   * **Fact Table Grain**: Confirmed uniqueness at (order_key, product_key) level
   * **Silver to Gold Reconciliation**: Documented 3-row difference (orphan products filtered)

4. **Data Enrichment**
   * Added human-readable attributes:
     * `day_of_week_name` ("Sunday", "Monday", etc.)
     * `time_of_day_bucket` ("Morning", "Afternoon", "Evening", "Night")
     * `product_hierarchy` ("department / aisle / product")
   * Pre-aggregated customer lifetime metrics
   * Calculated reorder rates and rankings

#### Key Accomplishments

* ✅ Designed and implemented complete star schema
* ✅ Created 4 business analytics tables answering all business questions
* ✅ Achieved perfect referential integrity (0 orphans)
* ✅ Enriched dimensions with business-friendly attributes
* ✅ Pre-aggregated metrics for optimal dashboard performance
* ✅ Validated fact table grain uniqueness (33.8M rows, 0 duplicates)

#### Technical Skills Demonstrated

* Star schema dimensional modeling
* Fact and dimension table design
* Surrogate key generation (ROW_NUMBER)
* Pre-aggregation techniques
* Complex JOINs (including self-joins for basket analysis)
* Business logic implementation (reorder rates, time buckets)
* Data enrichment and denormalization

---

### Maeve — Business Analytics & Dashboard

**Primary Responsibility**: Dashboard development and business intelligence layer

#### Deliverables

1. **Business Analytics Dashboard**
   * Consumption layer built on Gold tables
   * Visualizations for all 4 business questions:
     * Product and department popularity analysis
     * Temporal patterns (heatmaps by day/hour)
     * Reorder behavior analysis
     * Market basket (product pair) analysis

2. **KPIs and Metrics**
   * Total Orders: 3.3M
   * Total Customers: 206K
   * Total Products: 49.7K
   * Reorder Rates: 40-85% (by product/department)
   * Peak Order Times: Sunday 2-3 PM, 10-11 AM
   * Most Popular Product: Banana (491K orders)

3. **Dashboard Features**
   * **Product Insights**: Top products and departments by order volume
   * **Temporal Analysis**: Order patterns by day of week and hour
   * **Customer Insights**: Reorder rates and basket sizes
   * **Cross-Sell Opportunities**: Product pairs frequently bought together

#### Key Accomplishments

* ✅ Built comprehensive business intelligence dashboard
* ✅ Translated technical data model into business insights
* ✅ Created visualizations answering all required business questions
* ✅ Provided actionable insights for business users
* ✅ Dashboard queries run in <1 second (optimized Gold layer)

#### Technical Skills Demonstrated

* Business intelligence dashboard design
* Data visualization best practices
* KPI definition and measurement
* Business analytics and insights generation
* Dashboard querying (consuming Gold tables)

---

### Angela — GitHub Notebook Organization

**Primary Responsibility**: Repository organization and query documentation

#### Deliverables

1. **GitHub Repository Structure**
   * Organized notebooks into clear pipeline layers
   * Structured documentation folder hierarchy
   * Maintained version control for all project files

2. **Per-Query Documentation**
   * Documented query structure and purpose
   * Organized code into logical sections:
     * Data ingestion queries
     * Data cleaning queries
     * Validation queries
     * Business analytics queries
   * Added descriptive cell titles for each query section

3. **Repository Management**
   * Maintained clean commit history
   * Organized files into appropriate directories
   * Ensured notebook readability and maintainability

#### Key Accomplishments

* ✅ Created professional GitHub repository structure
* ✅ Organized notebooks for easy navigation
* ✅ Documented query sections for clarity
* ✅ Maintained version control best practices

#### Technical Skills Demonstrated

* Git and GitHub proficiency
* Code organization and documentation
* Repository structure design
* Version control best practices

---

### Tina (Cristina) — Documentation + Star Schema Design

**Primary Responsibility**: Comprehensive project documentation and dimensional model design

#### Deliverables

1. **Project Documentation** (6 markdown files)
   
   * **README.md**
     * Project overview and objectives
     * Architecture diagram
     * Business questions documentation
     * Getting started guide
     * Team contributions summary
   
   * **docs/architecture.md**
     * Detailed system architecture
     * Layer-by-layer documentation (Source, Bronze, Silver, Gold, Dashboard)
     * Data flow and transformations
     * Table specifications with row counts
   
   * **docs/data_model.md**
     * Dimensional modeling concepts
     * Fact table design and grain definition
     * Dimension table design
     * Modeling decisions and rationale
     * Business question mapping to model
   
   * **docs/star_schema.md**
     * Visual star schema diagram (ASCII art)
     * Relationship specifications
     * Sample SQL queries (5 examples)
     * Design decisions and validation
   
   * **docs/data_dictionary.md**
     * Complete data dictionary for all tables
     * Column-level documentation (Bronze, Silver, Gold)
     * Data types, descriptions, keys, and roles
     * Data quality notes
   
   * **docs/decisions.md**
     * 12 key engineering decisions documented
     * Problem, decision, reason, consequence format
     * Architectural trade-offs explained
     * Design alternatives considered

   * **docs/team_contributions.md** (this document)
     * Detailed team member contributions
     * Deliverables and accomplishments
     * Skills demonstrated

2. **Star Schema Design**
   * Defined fact table grain (order line item)
   * Designed dimension structure (products, customers, orders)
   * Specified primary keys, foreign keys, measures
   * Created relationship diagrams
   * Validated dimensional model integrity

3. **Technical Specifications**
   * Documented 19 tables (6 Bronze, 5 Silver, 8 Gold)
   * Specified 200+ columns with full descriptions
   * Created 12 decision documents with rationale
   * Wrote 5 sample SQL queries
   * Validated all row counts and data quality metrics

#### Key Accomplishments

* ✅ Created 7 comprehensive documentation files (5,000+ lines)
* ✅ Designed star schema following Kimball methodology
* ✅ Documented 100% of tables and columns
* ✅ Explained all engineering decisions with rationale
* ✅ Created professional, presentation-ready documentation
* ✅ Validated dimensional model with SQL proof queries
* ✅ Mapped business questions to data model

#### Technical Skills Demonstrated

* Technical writing and documentation
* Dimensional modeling (Kimball methodology)
* Star schema design
* Data dictionary creation
* Architectural documentation
* Markdown formatting and organization
* Business requirements translation
* Data modeling validation

---

## Collaboration and Integration

### Pipeline Integration

The team worked sequentially through the Medallion Architecture:

```
Nadine (Bronze) → Ina (Silver) → Cath (Gold) → Maeve (Dashboard)
                                       ↓
                            Tina (Documentation)
                                       ↓
                            Angela (Organization)
```

### Cross-Team Coordination

1. **Nadine → Ina**
   * Nadine's Bronze tables served as input to Ina's Silver layer
   * Data quality issues (type errors) identified by Nadine, resolved by Ina
   * Row count baselines established by Nadine, reconciled by Ina

2. **Ina → Cath**
   * Ina's Silver tables provided clean input to Cath's Gold layer
   * Orphan products identified by Ina, filtered by Cath
   * Referential integrity validated by Ina, confirmed by Cath

3. **Cath → Maeve**
   * Cath's Gold tables optimized for Maeve's dashboard queries
   * Pre-aggregated analytics tables created by Cath for Maeve's visualizations
   * Business metrics calculated by Cath, visualized by Maeve

4. **All → Tina**
   * Tina documented implementation by Nadine, Ina, and Cath
   * Tina specified dimensional model implemented by Cath
   * Tina documented business analytics consumed by Maeve

5. **All → Angela**
   * Angela organized notebooks created by Nadine, Ina, and Cath
   * Angela structured documentation created by Tina
   * Angela maintained repository for team collaboration

---

## Project Statistics

### Code and Data

* **Total Tables Created**: 19 (6 Bronze + 5 Silver + 8 Gold)
* **Total Rows Processed**: 37+ million source records
* **Final Fact Table Size**: 33,819,103 order line items
* **Total Dimensions**: 3 (products, customers, orders)
* **Business Analytics Tables**: 4 (popularity, temporal, reorder, basket)
* **Validation Queries**: 20+ data quality checks

### Documentation

* **Documentation Files**: 7 markdown files
* **Total Documentation Lines**: 5,000+ lines
* **Tables Documented**: 19 (100% coverage)
* **Columns Documented**: 200+
* **Engineering Decisions**: 12 documented
* **Sample SQL Queries**: 5 provided

### Timeline

* **Sprint Duration**: [TO CONFIRM with team]
* **Bronze Layer**: Week 1
* **Silver Layer**: Week 1-2
* **Gold Layer**: Week 2-3
* **Dashboard**: Week 3
* **Documentation**: Week 3-4

---

## Skills Summary by Team Member

### Data Engineering Skills

| Skill | Nadine | Ina | Cath | Maeve | Angela | Tina |
|-------|--------|-----|------|-------|--------|------|
| SQL DDL/DML | ✅ | ✅ | ✅ | ✅ | | |
| Data Ingestion | ✅ | | | | | |
| Data Cleaning | | ✅ | | | | |
| Data Validation | ✅ | ✅ | ✅ | | | |
| Dimensional Modeling | | | ✅ | | | ✅ |
| Star Schema Design | | | ✅ | | | ✅ |
| Pre-Aggregation | | | ✅ | | | |
| Dashboard Development | | | | ✅ | | |
| Technical Writing | | | | | | ✅ |
| Git/GitHub | | | | | ✅ | |

### Business Skills

| Skill | Nadine | Ina | Cath | Maeve | Angela | Tina |
|-------|--------|-----|------|-------|--------|------|
| Requirements Analysis | | | | ✅ | | ✅ |
| Business Intelligence | | | | ✅ | | |
| Data Quality Management | ✅ | ✅ | ✅ | | | |
| Documentation | ✅ | ✅ | ✅ | | | ✅ |
| Project Organization | | | | | ✅ | |

---

## Lessons Learned

### Technical Lessons

1. **Data Type Validation is Critical**
   * Ina discovered STRING columns that should be INT
   * Early validation prevents downstream issues

2. **Referential Integrity Matters**
   * 3 orphan products identified early
   * Transparent documentation better than silent filtering

3. **Pre-Aggregation Improves Performance**
   * Cath's business analytics tables enable <1s dashboard queries
   * Trade-off: storage vs query performance

4. **Grain Definition is Fundamental**
   * Order line item grain enables all business questions
   * Clear grain definition prevents confusion

### Process Lessons

1. **Medallion Architecture Works**
   * Clear separation of concerns (Bronze, Silver, Gold)
   * Each layer has distinct purpose and owner

2. **Validation at Every Layer**
   * Nadine, Ina, and Cath each validated their layer
   * Early issue detection prevents downstream problems

3. **Documentation Enables Collaboration**
   * Tina's documentation helps team understand design decisions
   * Angela's organization makes code navigable

---

## Acknowledgments

This project was completed as part of **FTW Data Engineering Batch 12** training program.

**Special Thanks:**
* FTW Foundation for providing training and resources
* Databricks platform for enabling cloud-based data engineering
* Instacart for providing the dataset

**Team Recognition:**
Every team member contributed essential skills and expertise:
* **Nadine** laid the foundation with Bronze ingestion
* **Ina** ensured data quality with Silver cleaning
* **Cath** created the analytical model with Gold dimensional design
* **Maeve** delivered business value with the dashboard
* **Angela** maintained organization and structure
* **Tina** documented the entire project for future reference

---

**Project**: Engineer Instacart  
**Team**: FTW Data Engineering Batch 12  
**Completion Date**: September 2026  
**Document Owner**: Tina (Cristina)  
**Last Updated**: September 2, 2026