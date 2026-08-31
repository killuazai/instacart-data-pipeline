# Instacart Data Engineering Pipeline

## Project Overview

This repository contains the group implementation of the FTW Batch 12 Instacart Data Engineering homework.

Required flow:

`INSTACART -> BRONZE -> SILVER -> GOLD -> DASHBOARD`

The repository is organized so another engineer can understand the project, run the pipeline, validate the outputs, and continue the work without needing to ask the original team questions.

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
4. Team question: What additional business question can this data help answer?

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
│   ├── 01_bronze/sql/
│   ├── 02_silver/sql/
│   ├── 03_gold/sql/
│   └── 04_business_questions/sql/
├── tests/
├── dashboards/
│   ├── README.md
│   └── screenshots/
└── notebooks/
    └── README.md
```

## Pipeline Architecture

```text
Instacart CSV source
        |
        v
     Bronze
  raw source copy
        |
        v
     Silver
 cleaned and validated
        |
        v
      Gold
 dimensional model
        |
        v
    Dashboard
 business questions
```

See `docs/architecture.md` for the detailed version.

## Data Model

Complete this section after the Gold model is finalized.

- Business process: [TODO]
- Fact table: [TODO]
- Grain: [TODO - describe exactly what one fact row represents]
- Measures: [TODO]
- Dimensions: [TODO]
- Primary keys: [TODO]
- Foreign keys: [TODO]
- Relationships: [TODO]

See `docs/data_model.md` and `docs/diagrams/`.

## How to Run

1. Open the project in Databricks.
2. Run the setup SQL in `src/00_setup/`.
3. Run the Bronze SQL files in `src/01_bronze/sql/`.
4. Run the Bronze validation in `tests/`.
5. Run the Silver SQL files in `src/02_silver/sql/`.
6. Run the Silver validation in `tests/`.
7. Run the Gold SQL files in `src/03_gold/sql/`.
8. Run the Gold validation in `tests/`.
9. Run the business-question SQL files in `src/04_business_questions/sql/`.
10. Refresh or rebuild the dashboard from the validated Gold outputs.

Do not continue downstream when a validation check fails. Fix the root cause, rebuild the affected layer, then validate again.

## Validation

Validation should include, where relevant:

- row counts
- null required keys
- duplicate keys
- data types and valid ranges
- source-to-target row preservation
- missing relationships or unmatched joins
- grain preservation
- measure reconciliation

See `docs/validation.md` and `tests/`.

## Engineering Decisions

Record decisions that change structure, grain, joins, cleaning rules, or dashboard behavior in `docs/decisions.md`.

## Team Contributions

Each teammate should contribute through a branch and pull request. Track the final ownership and merged contributions in `docs/team_contributions.md`.

## Dashboard

Add dashboard details and screenshots in `dashboards/`.
