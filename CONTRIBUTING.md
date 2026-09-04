# Contributing Guide

Thank you for contributing to the Instacart data pipeline. This guide keeps changes consistent across the Databricks notebooks, extracted SQL, validation tasks, documentation, and dashboard.

## Project Workflow

Use the following collaboration flow:

`ISSUE -> ASSIGN OWNER -> PULL -> BRANCH -> CHANGE -> VALIDATE -> PULL REQUEST -> REVIEW -> REVISE -> APPROVE -> MERGE`

Do not create permanent folders for individual contributors. Organize work by pipeline layer or deliverable so the repository remains understandable after the project is handed off.

## Issue and Reviewer Workflow

Every task should begin with a GitHub issue created by the reviewer. The issue is the shared record of the requested work, its scope, and the result expected from the branch owner.

1. The reviewer opens an issue describing the problem or requested improvement.
2. The reviewer includes the affected pipeline layer or files, acceptance criteria, and any validation that must pass.
3. The issue is assigned to the team member who will own the working branch.
4. The branch owner creates a focused branch for that issue and completes the requested task.
5. The branch owner opens a pull request, links the issue, and summarizes the implementation and validation results.
6. The reviewer checks the pull request and leaves suggestions, questions, or required changes as review comments.
7. The branch owner addresses every reviewer comment by updating the branch or explaining the decision when a change is not appropriate.
8. After revisions are pushed, the branch owner replies to the relevant comments and requests another review.
9. The reviewer confirms that the issue's acceptance criteria and requested changes have been satisfied before approving the pull request.
10. The pull request is merged only after reviewer approval. The linked issue is then closed, preferably through a pull request keyword such as `Closes #42`.

Reviewer comments are part of the task, not optional notes. The branch owner should follow actionable suggestions, ask for clarification when a comment is unclear, and avoid resolving a conversation until the feedback has been addressed.

## Before Starting

1. Read the assigned GitHub issue and confirm its acceptance criteria.
2. Ask the reviewer to clarify any missing or ambiguous requirement before implementation.
3. Pull the latest `main` branch.
4. Review [README.md](README.md) for the current architecture and execution order.
5. Check [REPO_TREE.txt](REPO_TREE.txt) to locate the canonical notebook and its matching source or test file.
6. Create a focused branch for the assigned issue.
7. Confirm which downstream layers, tests, documentation, and dashboard datasets may be affected.

## Branch Naming

Use a short lowercase branch name with hyphens.

Include the GitHub issue number when possible so the branch is easy to trace back to its assignment.

Examples:

- `feature/42-bronze-products`
- `feature/43-silver-orders`
- `feature/44-gold-model`
- `feature/45-analytics-product-pairs`
- `fix/46-silver-schema-context`
- `test/47-gold-reconciliation`
- `docs/48-data-model`
- `dashboard/49-reorder-view`

## Canonical Pipeline Order

The four numbered notebooks are the main end-to-end execution path:

1. `notebooks/01_bronze_instacart_notebook.ipynb`
2. `notebooks/02_silver_instacart_notebook.ipynb`
3. `notebooks/03_gold_instacart_notebook.ipynb`
4. `notebooks/04_analytics_instacart_notebook.ipynb`

Pipeline schemas:

| Layer | Schema |
| --- | --- |
| Bronze | `workspace.instacart_bronze` |
| Silver | `workspace.instacart_silver` |
| Gold | `workspace.instacart_gold` |
| Analytics | `workspace.instacart_analytics` |

When running Silver in a fresh Databricks session, explicitly select its target before executing its unqualified table statements:

```sql
USE CATALOG workspace;
USE SCHEMA instacart_silver;
```

## Where to Make Changes

| Change type | Primary location | Keep synchronized with |
| --- | --- | --- |
| End-to-end stage logic or notebook documentation | `notebooks/` | Matching task files under `src/` and `tests/` |
| Individual build task | `src/<layer>/sql/` | Corresponding code cell in the numbered notebook |
| Validation or reconciliation | `tests/` | Corresponding validation cell and `docs/validation.md` |
| Architecture, grain, keys, or layer behavior | `docs/` | `README.md` and affected notebook Markdown |
| Analytics dataset | `notebooks/04_analytics_instacart_notebook.ipynb` or `src/04_analytics/` | Dashboard datasets and `dashboards/README.md` |
| Dashboard layout or dataset query | `dashboards/Instacart Business Insights.lvdash.json` | `dashboards/README.md` and Analytics outputs |
| Repository structure | Relevant files or folders | `REPO_TREE.txt` and the README structure section |

If the same SQL exists in a notebook and a standalone file, update both in the same pull request. Reviewers should not have to guess which copy is current.

## Project-Specific Data Rules

Preserve these meanings unless a design change is explicitly agreed and documented:

- Bronze is a typed source copy; business cleaning belongs in Silver.
- `_rescued_data` belongs in Bronze for malformed-record monitoring.
- `days_since_prior_order` is expected to be null for a customer's first order.
- `add_to_cart_order` is basket position, not product quantity.
- `reordered` represents repeat-purchase behavior and becomes Boolean in Silver.
- Prior and train order-product files remain separate in Bronze and are combined in Silver.
- The analytical event grain is one product line in one order.
- The canonical dashboard reads the seven `workspace.instacart_analytics.analytics_*` tables.

The current Gold pipeline validates primary- and foreign-key rules but does not register those rules as Unity Catalog constraints. Do not describe the checks as enforced constraints unless the implementation is changed accordingly.

## Validation Requirements

Run the validation closest to the layer you changed, plus any affected downstream validation.

| Changed area | Minimum validation |
| --- | --- |
| Setup or Bronze | Source-file checks and `tests/08_validate_bronze.sql` |
| Silver | `tests/14_validate_silver.sql` |
| Gold dimensions | `tests/18_validate_gold_pre_constraints.sql`, `src/03_gold/sql/19_gold_constraints.sql`, and `tests/20a_validate_gold_final.sql` |
| Gold fact or measures | `src/03_gold/sql/19_gold_constraints.sql`, `tests/20a_validate_gold_final.sql`, and `tests/20b_gold_final_validation.dbquery.ipynb` |
| Analytics | `tests/25_validate_analytics.sql.dbquery.ipynb` |
| Dashboard | Refresh every affected dataset and inspect the changed visualizations |

Bronze uses `assert_true` and should stop on failure. Silver, Gold, and Analytics currently return `PASS` or `REVIEW`; a `REVIEW` result must be investigated and explained before merge.

When source data has not changed, expected checks include:

- Bronze: six `PASS` rows and exact approved row counts.
- Silver: five `PASS` rows after documented cleaning.
- Gold pre-check: two `PASS` rows.
- Gold key and relationship checks: eight `PASS` rows with zero violations.
- Gold table reconciliation: three `PASS` rows.
- Gold measure reconciliation: five `PASS` rows with zero differences.
- Analytics: seven `PASS` rows.

Do not claim a successful Databricks run based only on static code review. Record whether the SQL was executed and which result sets were observed.

## Documentation Requirements

Update documentation in the same pull request when a change affects:

- Source files or expected row counts.
- Table names, schemas, columns, or data types.
- Grain, key definitions, or relationships.
- Cleaning, filtering, or reconciliation behavior.
- Analytics metric definitions, thresholds, ranking limits, or materialization.
- Dashboard datasets, visuals, filters, findings, or refresh steps.
- Pipeline dependencies or execution order.

Use exact current object names. Avoid carrying older names such as `fact_order_items`, `dim_customers`, or `gold_product_popularity` into documentation for the canonical pipeline.

## Before Opening a Pull Request

- Rebase or merge the latest `main` according to the team's chosen workflow.
- Run the changed SQL in Databricks when access is available.
- Run all relevant validation and downstream reconciliation tasks.
- Confirm notebook files and dashboard exports are valid JSON.
- Confirm notebook SQL matches the corresponding files under `src/` and `tests/`.
- Remove secrets, tokens, personal paths, temporary outputs, and downloaded source data.
- Update the README, detailed docs, dashboard guide, and repository tree when affected.
- Review the final diff for unrelated or generated changes.

## Pull Requests

Keep each pull request focused on one logical contribution where possible. Good scopes include:

- One Bronze ingestion improvement.
- One Silver cleaning rule.
- One Gold dimension or fact change.
- One validation improvement.
- One analytics question or metric.
- One dashboard update.
- One coordinated documentation correction.

Include the following information in the pull request description:

1. The linked GitHub issue, using `Closes #<issue-number>` when the pull request fully resolves it.
2. What changed and why.
3. Which pipeline layers or objects are affected.
4. How the change was tested.
5. The observed validation results.
6. Any documented row-count differences or known limitations.
7. Screenshots for dashboard changes, when useful.

## Review Checklist

Reviewers should confirm that:

- The SQL matches the stated purpose and grain.
- Joins cannot unintentionally multiply rows.
- Filters do not silently remove unexplained records.
- Counts and rates use the correct denominator.
- `add_to_cart_order` is not treated as quantity.
- Key and relationship checks match the model described in the docs.
- Large-table operations are reasonable for the 33.8-million-row fact.
- Notebook and standalone task copies remain synchronized.
- Documentation describes the implemented behavior rather than an earlier design.

## Commit Messages

Use short, imperative messages that describe the result.

Examples:

- `Fix Silver product reference filtering`
- `Add Gold measure reconciliation`
- `Document Analytics dashboard refresh`
- `Align repository tree with tracked files`
