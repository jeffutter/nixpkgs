# Scripts

Read this file when a task needs monthly spending, category averages, or budgets set to actual spending.

Run each script from the budget project root with `python3 <skill-dir>/scripts/<script>.py`. The `actual` CLI reads its config from the current directory. Amounts print in dollars. `--json` output is in cents, keyed by category ID.

## spending_by_month.py

Prints spending by category for one month. It reports only categories with net outflow.

```bash
python3 <skill-dir>/scripts/spending_by_month.py 2025-08 [--skip CAT_ID ...] [--json]
```

## category_averages.py

Prints average, min, and max spending per category across complete months. A month with no spending counts as $0. The "Present" column counts months with spending.

```bash
python3 <skill-dir>/scripts/category_averages.py 2025-08 2025-09 2025-10 [--skip CAT_ID ...] [--json]
```

## set_budget_to_actuals.py

Sets each expense category's budget to that month's spending. Takes one or more months.

```bash
python3 <skill-dir>/scripts/set_budget_to_actuals.py 2025-08 2025-09 [--skip CAT_ID ...] [--zero CAT_ID ...] [--dry-run]
```

- `--skip`: leave these categories' budgets unchanged. Pass income and starting-balance categories here.
- `--zero`: set these categories' budgets to 0, such as a category whose transactions became transfers.
- `--dry-run`: print the changes and make no API calls. Run this first.
