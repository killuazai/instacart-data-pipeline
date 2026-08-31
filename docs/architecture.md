# Architecture

## Purpose

Explain how Instacart data moves from source files to business-ready outputs.

## Data Flow

```text
Instacart Source
      |
      v
   Bronze
      |
      v
   Silver
      |
      v
    Gold
      |
      v
 Dashboard
```

## Source

Document the approved Instacart source files and their Databricks location here.

## Bronze

Document:

- what is loaded
- source grain of each dataset
- schema handling
- ingestion decisions
- Bronze validation gate

## Silver

Document:

- cleaning and standardization
- data type corrections
- handling of prior/train order-product data
- relationship checks
- Silver validation gate

## Gold

Document:

- business process
- fact table
- dimensions
- grain
- keys and relationships
- Gold validation gate

## Dashboard

Document which Gold outputs support each visualization and business question.

## Run Order

Add the exact SQL execution order after the team finalizes the pipeline.
