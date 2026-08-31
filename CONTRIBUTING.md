# Contributing Guide

## Team Workflow

Use this simple collaboration flow:

`PULL -> CHANGE -> COMMIT -> PUSH -> PULL REQUEST -> REVIEW -> MERGE`

## Branch Naming

Use a short branch name tied to one task.

Examples:

- `feature/bronze-products`
- `feature/silver-orders`
- `feature/gold-model`
- `feature/q1-products-departments`
- `docs/data-model`

Do not create permanent folders per teammate. Organize the repository by engineering layer and deliverable so the project remains understandable after handoff.

## Before Starting Work

1. Pull the latest `main`.
2. Create a branch for your task.
3. Edit only the files required for that task.

## Before Opening a Pull Request

- Run the SQL you changed.
- Run the relevant validation checks.
- Confirm the file is saved in the correct folder.
- Update documentation when your change affects architecture, model, grain, keys, validation, or decisions.

## Pull Requests

Keep each pull request focused on one logical contribution when possible.

Examples:

- one Bronze table
- one Silver transformation
- one Gold table
- one business question
- one documentation file
- one validation improvement

Use the pull request template in `.github/pull_request_template.md`.
