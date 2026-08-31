# Validation

Validation is part of the pipeline and should be completed before moving downstream.

## Bronze Validation

Record:

- source vs Bronze row counts
- null required identifiers
- duplicate candidate keys
- rescued or malformed rows
- expected source files

## Silver Validation

Record:

- Bronze vs Silver row preservation
- null required keys
- duplicate keys and grain
- valid ranges
- valid `eval_set` values
- missing product, aisle, department, or order relationships

## Gold Validation

Record:

- Silver vs Gold fact row reconciliation
- dimension key uniqueness
- fact grain uniqueness
- null foreign keys
- unmatched relationships
- measure reconciliation
- PK/FK constraints if used

## Business Question Validation

For every dashboard query, write the reconciliation or reasonableness check used to confirm the result.

## Validation Evidence

| Layer / Query | Check | Expected | Actual | Status | Owner |
|---|---|---|---|---|---|
| [TODO] | [TODO] | [TODO] | [TODO] | PASS / REVIEW | [TODO] |
