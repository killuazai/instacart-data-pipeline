# Silver Layer Decisions for Review

From Ina, for review/merge into `decisions.md`.


**1. order_products union happens in Silver, not Bronze**
Bronze keeps prior/train as two separate tables (mirrors the source files). Silver unions them into one, since the split is just a leftover from Kaggle's ML competition setup, not a real business distinction.

**2. Backslash bug in product_name, fixed in Silver**
120 rows had a stray `\` character (bad escaping in the source CSV, `\""` instead of `"`). Fixed with `REPLACE(product_name, CHR(92), '')` in `silver_products`.

**3. row_difference doesn't fail validation**
Silver intentionally drops rows (orphan FKs, bad ranges), so row counts won't match Bronze exactly. `status` only checks for remaining nulls/duplicates/FK issues, not row count.

**4. Two Silver tables depend on other Silver tables, not just Bronze**
`silver_products` needs `silver_aisles` + `silver_department` done first. `silver_order_products` needs `silver_orders` done first. Both check `EXISTS` against the cleaned tables, not Bronze — needs explicit Job task dependencies or risks a race condition.

**5. days_since_prior_order NULLs kept, not filled**
NULL means it's the user's first order — real data, not missing data.

**6. Use INSTR(), not LIKE, to check for a backslash**
`LIKE CONCAT('%', CHR(92), '%')` gave false positives, Spark treats backslash as a pattern escape character, so it was matching on `%` symbols instead. `INSTR(column, CHR(92)) > 0` is the safe way to check. Worth checking if this pattern shows up in anyone else's validation scripts too.
