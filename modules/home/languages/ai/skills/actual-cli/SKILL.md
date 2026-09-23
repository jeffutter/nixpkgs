---
name: actual-cli
description: Use when querying, managing, or automating Actual Budget via the command line - accounts, transactions, budgets, categories, payees, schedules, rules, or AQL queries against an Actual Budget server.
---

# actual-cli

Use this skill when a task reads or changes data on an Actual Budget server through the `actual` command. The task ends when the command output confirms the read or write.

## Fixed values

- Skill directory: the directory containing this file. Call it `<skill-dir>`.
- Amounts are integer cents. `5000` is $50.00. `-12350` is -$123.50.
- Negative amounts are expenses. Positive amounts are income.
- AQL tables: `transactions`, `accounts`, `categories`, `payees`, `rules`, `schedules`.
- Transaction fields: `id`, `date`, `amount`, `notes`, `cleared`, `reconciled`, `is_parent`, `is_child`, `account`, `payee`, `category`, `transfer_id`.
- Joined transaction fields: `account.name`, `payee.name`, `category.name`, `category.group.name`.

## Steps

1. Configure the connection.
   - Set `ACTUAL_SERVER_URL` and `ACTUAL_SYNC_ID`. Both are required.
   - Set `ACTUAL_PASSWORD` or `ACTUAL_SESSION_TOKEN`.
   - Set `ACTUAL_ENCRYPTION_PASSWORD` if the budget uses end-to-end encryption.
   - Set `ACTUAL_DATA_DIR` to choose the local cache directory.
   - Config files work instead of variables. The CLI searches `.actualrc`, `.actualrc.json`, `actual.config.json`, then `package.json`.
   - Flags override variables: `--server-url`, `--password`, `--session-token`, `--sync-id`, `--data-dir`, `--encryption-password`, `--verbose`.
   - For a self-signed server certificate, set `NODE_EXTRA_CA_CERTS=<path-to-ca.pem>`.
   - When debugging an unexpected error, run `actual server version`. The API changes between versions.

2. Resolve every name to an ID. Commands take IDs, not names.
   - Run `actual server get-id --type <accounts|payees|schedules> --name "<name>"`.
   - For categories, run `actual categories list --format json` and filter with `jq`. `get-id --type categories` crashes on some names.
   - For payees, query with `$like`. One business often has several payee names, such as "Blue Moose Topek" and "Blue Moose Bar & Grill".
   - Select `payee` next to `payee.name` when a later step needs the payee ID.

3. Read data. Pick the command for the task.
   - `actual accounts list [--include-closed]`
   - `actual accounts balance <id> [--cutoff YYYY-MM-DD]`. Use this for balances. The `balance` field in `accounts list` can read `0` wrongly.
   - `actual budgets list`, `actual budgets months`, `actual budgets month YYYY-MM`
   - `actual categories list`, `actual category-groups list`
   - `actual payees list`, `actual payees common`, `actual tags list`
   - `actual rules list`, `actual rules payee-rules <payeeId>`
   - `actual schedules list`
   - `actual transactions list --account <id> --start YYYY-MM-DD --end YYYY-MM-DD`
   - `actual query tables` and `actual query fields <table>` show the AQL schema.

4. Query with AQL for filtered or aggregated reads.
   - Last N transactions: `actual query run --last 10`.
   - Filtered: `actual query run --table transactions --select "date,amount,payee.name,category.name" --filter '<json>' --order-by "date:desc" --limit 20 [--offset 20]`.
   - Count: add `--count`.
   - Filter operators: `$eq $ne $lt $lte $gt $gte $like $and $or`.
   - Wrap two or more filter conditions in `$and`: `{"$and":[{"date":{"$gte":"2026-01-01"}},{"date":{"$lte":"2026-01-31"}}]}`. A flat object with a date range can return all rows.
   - Filter on raw ID fields, such as `"category":"<id>"`. Joined fields like `category.name` work only in `--select`.
   - Add `{"is_parent":false}` when summing amounts. Split parents repeat their children's total.
   - `category.name` is `null` for uncategorized transactions.
   - Group by: pipe a JSON query to `--file -`: `echo '{"table":"transactions","groupBy":["category.name"],"select":["category.name",{"amount":{"$sum":"$amount"}}]}' | actual query run --file -`.
   - Pass `--format json` to `query run`. `--format table` prints `[object Object]`.

5. Write data. Pick the command for the task.
   - Accounts: `accounts create --name "<n>" [--offbudget] [--balance <cents>]`, `accounts update <id> [--name] [--offbudget true]`, `accounts close <id> [--transfer-account <id>] [--transfer-category <id>]`, `accounts reopen <id>`, `accounts delete <id>`.
   - Budgets: `budgets download <syncId>`, `budgets sync`, `budgets set-amount --month YYYY-MM --category <id> --amount <cents>`, `budgets set-carryover --month YYYY-MM --category <id> --flag true`, `budgets hold-next-month --month YYYY-MM --amount <cents>`, `budgets reset-hold --month YYYY-MM`.
   - Transactions: `transactions add --account <id> --data '[{"date":"2026-01-15","amount":-4500,"payee_name":"Coffee Shop","notes":"x"}]'` or `--file <path>`. `transactions import` takes the same input plus `[--dry-run]`. `transactions update <id> --data '{"cleared":true}'`. `transactions delete <id>`.
   - Categories and groups: `categories create --name "<n>" --group-id <id> [--is-income]`, `categories update <id> [--name] [--hidden true]`, `categories delete <id> [--transfer-to <id>]`. `category-groups` takes the same subcommands without `--group-id`.
   - Payees: `payees create --name "<n>"`, `payees update <id> --name "<n>"`, `payees delete <id>`, `payees merge --target <id> --ids id1,id2`.
   - Tags: `tags create --tag "<t>" [--color "#ff0000"] [--description "<d>"]`, `tags update <id>`, `tags delete <id>`.
   - Rules: `rules create --data '{"stage":"pre","conditionsOp":"and","conditions":[...],"actions":[...]}'`, `rules update --data '{...}'`, `rules delete <id>`.
   - Schedules: see `schedules.md`.
   - Bank sync: `actual server bank-sync`.
   - `transactions add` returns `"ok"`, not an ID. To reference the new transaction later, generate a UUID and pass it as `id`.
   - Run commands one at a time. Each call opens a new server connection.

6. Create transfers.
   - Use the transfer payee of the destination account. Find it in `actual payees list`: its `transfer_acct` equals the account ID.
   - Between two on-budget accounts, set `category` to `null`.
   - From an on-budget account to an off-budget account, set a category such as "Investments" or "Savings". A null category here stays uncategorized forever.
   - To convert an existing transaction to an on-budget transfer:
     1. Generate a UUID for the mirror.
     2. Add the mirror in the destination account with `"id":"<uuid>"`. Leave `transfer_id` out of the `add` data. `add` with `transfer_id` creates a duplicate mirror.
     3. Update the mirror with `"transfer_id":"<original-id>"`.
     4. Update the original with `"payee":"<dest-transfer-payee-id>"`, `"category":null`, `"transfer_id":"<uuid>"`.
   - Set `transfer_id` only to an existing transaction ID or `null`. Any other string creates a phantom transaction.
   - Match the two sides of a transfer by `transfer_id`. Bank sync can give each side a different date.

7. Parse the output. JSON is the default format. `--format table` and `--format csv` exist for display.
   - `query run` returns `{"data":[...],"dependencies":[...]}`. Read `.data`.
   - `list` commands return a flat array.
   - `transactions update` and `transactions delete` return `{"success":true,"id":"..."}`.
   - `accounts create` returns `{"id":"..."}`.
   - Inspect an unknown shape first: `... --format json | jq 'if type=="object" then keys else .[0] end'`.

## Reference files

Read a file when the task needs it:
- `concepts.md`: envelope model, To Budget, rollover, on-budget vs off-budget.
- `workflow.md`: setup, category structure, monthly cycle, deficit months, historical To Budget cleanup.
- `transactions.md`: transfer mechanics, rule stages and fields, reconciliation, splits, import vs add.
- `schedules.md`: creating schedules, matching windows, auto-entry.
- `credit-cards.md`: credit card setup and payment.
- `recipes.md`: Python scripts for monthly spending, category averages, and setting budgets to actuals.
