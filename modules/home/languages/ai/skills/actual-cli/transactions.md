# Transfers, rules, reconciliation, splits

Read this file for transfer mechanics, rule design, reconciliation, or split transactions.

## Transfers

- A transfer is two linked transactions. Updating one side updates the other.
- Deleting either side deletes both.
- To create a transfer from imported data, import into one account, then set the transfer payee. Actual creates the matching side.
- Category and ID rules for transfers live in SKILL.md step 6.

## Rules

Rules run on import and bank sync. Each rule matches conditions, then applies actions.

- Stages run in this order: `pre` (payee renaming), `default`, `post` (overrides).
- Actual sorts `default` rules from broadest to narrowest condition.
- Condition operators: `is`, `is not`, `contains`, `does not contain`, `matches` (regex), `one of`, `not one of`. String matching ignores case.
- Condition fields: imported payee, payee, account, category, date, notes, amount.
- Action fields: category, payee, notes, cleared, account, date, amount.
- Create one rule per payee ID. Find all payee IDs for a business with a `$like` query first.
- Inspect a payee's rules with `actual rules payee-rules <payeeId>`.

## Reconciliation

A transaction is uncleared, cleared, or reconciled (locked).

1. Run `actual accounts balance <id>`.
2. Compare each transaction to the bank statement.
3. Set `"cleared": true` on each matching transaction with `transactions update`.
4. Stop when the cleared balance equals the statement balance.
5. Set `"reconciled": true` on those transactions to lock them.

For an off-budget asset (property, vehicle, investment), add a transaction for the value change during reconciliation.

## Split transactions

- The parent has `is_parent: true` and holds the total.
- Each child has `is_child: true` and a `parent_id`. Children carry the category spending.
- Filter `"is_parent": false` when summing.

## Import vs add

- `transactions add` inserts rows with no deduplication.
- `transactions import` deduplicates on `imported_id`. Preview with `--dry-run`.
- Use `import` for any job that may run more than once.
