# Scripts & Recipes

Executable scripts live in `scripts/`. Run them directly with `python3`. All require the standard `.actualrc.yaml` config to be present in the **current working directory** — run them from the budget project root, not from the skill directory.

## Post-processing JSON output

Different commands return different JSON shapes — know which before you parse:

| Command type | Output shape | Access rows with |
|---|---|---|
| `query run` | `{"data": [...], "dependencies": [...]}` | `data["data"]` |
| `accounts list`, `categories list`, etc. | `[...]` (flat array) | `data` directly |
| `transactions add` | `"ok"` (string) | n/a — no useful data returned |
| `transactions update/delete` | `{"success": true, "id": "..."}` | `data["id"]` |
| `accounts create` | `{"id": "..."}` | `data["id"]` |

Quick one-liner pattern for inspecting output structure before writing a full script:

```bash
actual query run --table transactions --last 1 --format json | python3 -c "
import json, sys; data = json.load(sys.stdin); print(type(data), list(data.keys()) if isinstance(data, dict) else data[:1])
"
```

Always use `--format json` with `query run` — `--format table` renders as `[object Object]`.

---

## scripts/spending_by_month.py

Print actual spending by category for a given month.

```bash
python3 scripts/spending_by_month.py 2025-08
python3 scripts/spending_by_month.py 2025-08 --skip CAT_ID [CAT_ID ...]
python3 scripts/spending_by_month.py 2025-08 --json
```

- Excludes inflow categories automatically (only reports net-negative categories)
- `--json` outputs a dict keyed by category ID — useful for piping into other scripts

## scripts/category_averages.py

Compute average, min, and max spending per category across a list of complete months. Use this to set forward-looking budget targets.

```bash
python3 scripts/category_averages.py 2025-08 2025-09 2025-10 2025-11 2025-12 2026-01 2026-02 2026-03
python3 scripts/category_averages.py 2025-08 2025-09 ... --skip CAT_ID [CAT_ID ...]
python3 scripts/category_averages.py 2025-08 2025-09 ... --json
```

- Months with no spending for a category count as $0 in the average
- "Present" column shows how many of the given months had any spending in that category

## scripts/set_budget_to_actuals.py

Set each expense category's budget to match actual spending. Accepts one or more months. Useful for initial setup or backfilling historical months.

```bash
# Single month
python3 scripts/set_budget_to_actuals.py 2025-08

# Range of months
python3 scripts/set_budget_to_actuals.py 2025-08 2025-09 2025-10 2025-11 2025-12 2026-01 2026-02 2026-03

# Skip income/savings categories, zero out one that was converted to transfers
python3 scripts/set_budget_to_actuals.py 2025-08 \
  --skip 3c1699a5-522a-435e-86dc-93d900a14f0e \   # Income
         506e8d9d-7ed0-4397-84e4-07a9185dc6b2 \   # Starting Balances
  --zero 6bbd8472-25d4-4cee-8a11-5bd9f7e83d61     # Savings

# Preview without applying
python3 scripts/set_budget_to_actuals.py 2025-08 --dry-run
```

- `--skip`: leave those category budgets completely untouched
- `--zero`: explicitly set to $0 (e.g. a category whose transactions became transfers)
- `--dry-run`: prints what would be set without making any API calls
