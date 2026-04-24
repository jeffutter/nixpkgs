---
name: actual-cli
description: Use when querying, managing, or automating Actual Budget via the command line — accounts, transactions, budgets, categories, payees, schedules, rules, or AQL queries against an Actual Budget server.
---

# actual-cli

Command-line interface for Actual Budget. All commands connect to a running Actual server.

## Configuration

Prefer environment variables or a config file over CLI flags.

**Environment variables:**
```
ACTUAL_SERVER_URL=https://your-server    # required
ACTUAL_SYNC_ID=<budget-sync-id>          # required for most commands
ACTUAL_PASSWORD=<server-password>
ACTUAL_SESSION_TOKEN=<token>             # alternative to password
ACTUAL_DATA_DIR=<path>                   # local cache directory
ACTUAL_ENCRYPTION_PASSWORD=<pw>         # if budget uses E2E encryption
```

**Config files (searched in order):** `.actualrc`, `.actualrc.json`, `actual.config.json`, `package.json`

**Global flags** (override env vars):
```
--server-url  --password  --session-token  --sync-id
--data-dir  --encryption-password
--format json|table|csv   (default: json)
--verbose
```

## Amount Convention

**All monetary values are integer cents.** `5000` = $50.00, `-12350` = -$123.50.

Negative = expense/debit, positive = income/credit.

## Quick Reference

| Command | Description |
|---------|-------------|
| `actual accounts list` | All accounts |
| `actual budgets list` | Available budgets |
| `actual budgets sync` | Sync current budget |
| `actual budgets month YYYY-MM` | Budget data for a month |
| `actual categories list` | All categories |
| `actual category-groups list` | All category groups |
| `actual transactions list --account <id> --start YYYY-MM-DD --end YYYY-MM-DD` | List transactions |
| `actual payees list` | All payees |
| `actual tags list` | All tags |
| `actual rules list` | All transaction rules |
| `actual schedules list` | All scheduled transactions |
| `actual query run --last 10` | Last 10 transactions |
| `actual server get-id --type accounts --name "Checking"` | Look up ID by name |
| `actual server bank-sync` | Run bank sync |

## Resolving IDs

Most commands take `<id>` arguments. Use `server get-id` to resolve names to IDs:

```bash
actual server get-id --type accounts --name "Checking"
actual server get-id --type categories --name "Groceries"
actual server get-id --type payees --name "Amazon"
actual server get-id --type schedules --name "Rent"
```

## Accounts

```bash
actual accounts list [--include-closed]
actual accounts create --name "Savings" [--offbudget] [--balance 100000]
actual accounts update <id> [--name "New Name"] [--offbudget true]
actual accounts close <id> [--transfer-account <id>] [--transfer-category <id>]
actual accounts reopen <id>
actual accounts delete <id>
actual accounts balance <id> [--cutoff YYYY-MM-DD]
```

## Budgets

```bash
actual budgets list
actual budgets download <syncId> [--encryption-password <pw>]
actual budgets sync
actual budgets months
actual budgets month 2026-03
actual budgets set-amount --month 2026-03 --category <id> --amount 50000
actual budgets set-carryover --month 2026-03 --category <id> --flag true
actual budgets hold-next-month --month 2026-03 --amount 10000
actual budgets reset-hold --month 2026-03
```

## Transactions

```bash
actual transactions list --account <id> --start 2026-01-01 --end 2026-03-31
actual transactions add --account <id> --data '[{"date":"2026-01-15","amount":-4500,"payee_name":"Coffee Shop","notes":"work meeting"}]'
actual transactions add --account <id> --file transactions.json
actual transactions import --account <id> --data '[...]' [--dry-run]
actual transactions update <id> --data '{"notes":"updated note","cleared":true}'
actual transactions delete <id>
```

**Split transactions:** have `is_parent`/`is_child` fields. Filter `"is_parent": false` to avoid double-counting totals.

## Categories & Groups

```bash
actual categories list
actual categories create --name "Groceries" --group-id <id> [--is-income]
actual categories update <id> [--name "Food"] [--hidden true]
actual categories delete <id> [--transfer-to <id>]

actual category-groups list
actual category-groups create --name "Essentials" [--is-income]
actual category-groups update <id> [--name "New Name"] [--hidden true]
actual category-groups delete <id> [--transfer-to <id>]
```

## Payees & Tags

```bash
actual payees list
actual payees common
actual payees create --name "My Landlord"
actual payees update <id> --name "New Name"
actual payees delete <id>
actual payees merge --target <id> --ids id1,id2,id3

actual tags list
actual tags create --tag "vacation" [--color "#ff0000"] [--description "trip"]
actual tags update <id> [--tag "holiday"] [--color "#00ff00"]
actual tags delete <id>
```

## Rules & Schedules

```bash
actual rules list
actual rules payee-rules <payeeId>
actual rules create --data '{"stage":"pre","conditionsOp":"and","conditions":[...],"actions":[...]}'
actual rules update --data '{...}'
actual rules delete <id>

actual schedules list
actual schedules create --data '{...}'
actual schedules update <id> --data '{...}' [--reset-next-date]
actual schedules delete <id>
```

## AQL Queries

The most flexible way to read data. Tables: `transactions`, `accounts`, `categories`, `payees`, `rules`, `schedules`.

```bash
# Discover schema
actual query tables
actual query fields transactions

# Last N transactions (shorthand)
actual query run --last 10

# Select specific fields with filter
actual query run \
  --table transactions \
  --select "date,amount,payee.name,category.name" \
  --filter '{"amount":{"$lt":0}}' \
  --order-by "date:desc" \
  --limit 20

# Filter operators: $eq $ne $lt $lte $gt $gte $like $and $or
# Dot notation for joins: payee.name, category.name, category.group.name, account.name

# Count
actual query run --table transactions --filter '{"cleared":false}' --count

# Group by (requires --file for aggregate expressions)
echo '{"table":"transactions","groupBy":["category.name"],"select":["category.name",{"amount":{"$sum":"$amount"}}]}' \
  | actual query run --file -

# Pagination
actual query run --table transactions --order-by "date:desc" --limit 10 --offset 20
```

### Transaction fields (AQL)

Core: `id`, `date`, `amount`, `notes`, `cleared`, `reconciled`, `is_parent`, `is_child`
References: `account` (id), `payee` (id), `category` (id)
Joined strings: `account.name`, `payee.name`, `category.name`, `category.group.name`

## Output Formats

```bash
actual accounts list --format table    # human-readable with decimal amounts
actual accounts list --format csv      # for spreadsheet import
actual accounts list --format json     # default, machine-readable
```

## Common Gotchas

- **IDs everywhere:** Most commands need entity IDs, not names. Use `server get-id` first.
- **Amount in cents:** Easy to get wrong. $50 = `5000`, not `50`.
- **Split transactions:** Filter `is_parent: false` when summing to avoid double-counting.
- **Uncategorized:** `category.name` is `null` for uncategorized transactions.
- **Self-signed certs:** Set `NODE_TLS_REJECT_UNAUTHORIZED=0` (security risk — only in trusted environments).
- **Sequential requests:** Each invocation opens a new connection; avoid rapid-fire calls in loops.
- **Experimental:** API may change between versions; check `actual server version` when debugging.
- **`--format table` broken for `query run`:** AQL query results render as `[object Object]` with `--format table`. Always use `--format json` and post-process with `python3` or `jq` for human-readable output.
- **`server get-id --type categories` can crash:** Throws an unhandled promise rejection for some category names. Use `actual categories list --format json` and filter with python/jq instead.
- **Payees have multiple name variants:** The same business often appears under several slightly different payee names (e.g. "Blue Moose Topek" and "Blue Moose Bar & Grill"). Always search with `$like` to catch all variants, and create rules for each distinct payee ID found.
- **Fetch payee ID in the same query:** Include `payee` (the raw ID field) alongside `payee.name` in AQL selects when you'll need it for rule creation — avoids a second lookup round-trip.
- **AQL date range filters silently fail in flat JSON:** Combining a date range with other conditions using a flat JSON object (`{"date":{"$gte":"...","$lte":"..."},"other":...}`) can silently return all records instead of the filtered set. Always use explicit `$and` for multi-condition filters: `{"$and":[{"date":{"$gte":"..."}},{"date":{"$lte":"..."}},{"other":...}]}`.
- **`transactions add` returns `"ok"`, not the new transaction ID.** If you need to reference the created transaction (e.g. to link a transfer), pre-generate a UUID and pass it in the `id` field of the transaction data — Actual preserves it.
- **Dot-notation fields (e.g. `category.name`) work in `--select` but not in `--filter`.** Filter on the raw ID field instead (e.g. `"category": "<id>"`).
- **Transfer payees are auto-created when accounts are created.** They appear in `actual payees list` with a non-null `transfer_acct` field pointing to the account ID. Use these payees (not the regular merchant payees) when creating transfer transactions.
- **On-budget → off-budget transfers REQUIRE a category on the on-budget side.** Only on-budget ↔ on-budget transfers are category-free. Moving money to an investment or off-budget savings account is treated like an expense — categorize it (e.g. "Investments" or "Savings"). Do NOT try to make these category-null transfers; they will show as uncategorized in the UI forever.
- **Converting a categorized transaction to an on-budget ↔ on-budget transfer:** (1) pre-generate a UUID for the mirror, (2) create the mirror in the destination account with `"id": <uuid>` and `"transfer_id": <original-id>`, (3) update the original with `"payee": <dest-transfer-payee-id>`, `"category": null`, `"transfer_id": <uuid>`. Only do this for transfers between two on-budget accounts.
- **Setting `transfer_id` to a non-existent ID creates a phantom transaction.** Actual will create a real transaction with that literal string as its ID. Always use valid UUIDs or `null` for `transfer_id`.
- **Transfer dates can differ between sides.** Bank sync sometimes assigns different settlement dates to the debit and credit sides of the same transfer. Match transfers by `transfer_id`, not by date.
- **`transactions add` with `transfer_id` set creates a duplicate mirror.** If you pass `transfer_id` when adding a transaction, Actual may auto-create a second mirror — resulting in duplicate uncategorized transactions. Pre-generate the UUID and set `transfer_id` on both sides via separate `update` calls instead of relying on the `add` to wire the link.
- **`accounts list` balance field is unreliable.** The `balance` field returned by `accounts list --format json` can show `0` even when the account has transactions. Always use `accounts balance <id>` for an accurate current balance.

## Best Practices Reference

Load these when you need conceptual guidance beyond the command syntax:

| File | When to read |
|------|-------------|
| `concepts.md` | Envelope budgeting model, money flow, on/off-budget, rollover behavior, budgeting strategies |
| `workflow.md` | Monthly budgeting cycle, category structure, initial setup, savings categories, "To Budget" management |
| `transactions.md` | Transfer rules, transaction rules (stages/conditions/actions), reconciliation, split transactions, import vs add |
| `schedules.md` | Schedule patterns, matching windows, approximate amounts, auto-entry vs manual approval |
| `credit-cards.md` | How credit cards fit envelope budgeting, payment strategies, golden rules |
| `recipes.md` | Reusable Python scripts: monthly spending summary, multi-month averages, set budget to actuals |
