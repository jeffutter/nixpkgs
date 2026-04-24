# Transactions: Transfers, Rules & Reconciliation

## Transfers

Transfers link two transactions across accounts. Updating one side automatically updates the other.

**Category rules:**
- Between two on-budget accounts → no category (`_Transfer_`). Funds stay inside the budget; net effect is zero.
- Between off-budget and on-budget → requires a category on the on-budget side (it's income or an expense from the budget's perspective).

**Best practice:** Import to one account first, then create the transfer — the second account's transaction is created automatically and matches.

To delete a transfer: deleting either side removes both transactions.

## Transaction Rules

Rules run automatically on import/sync. They match conditions → apply actions, executing in the order they appear.

**Execution stages (in order):**
- `pre` — typically payee renaming; runs first
- `default` — standard rules; auto-ranked from least to most specific
- `post` — overrides; runs last

Rules within `default` stage are auto-sorted so broad conditions (e.g., "payee contains Amazon") run before narrow ones (e.g., "payee is amazon.com/books").

**Condition operators:** `is`, `is not`, `contains`, `does not contain`, `matches` (regex), `one of`, `not one of`. All string matching is case-insensitive.

**Condition fields:** imported payee, payee, account, category, date, notes, amount (inflow/outflow variants).

**Action fields:** category, payee, notes, cleared, account, date, amount.

**Auto-generated rules:**
- Renaming a payee → Actual offers to create a rule to rename it on future imports.
- Categorizing a payee repeatedly → Actual auto-creates a categorization rule.

Use `actual rules payee-rules <payeeId>` to inspect rules targeting a specific payee.

## Reconciliation

Reconciliation locks confirmed transactions to prevent accidental edits.

**Status states:**
- Uncleared — transaction exists but not yet matched to bank statement
- Cleared — matched to bank; turns green
- Reconciled/Locked — confirmed and locked after reconciliation

**Workflow:**
1. Run `actual accounts balance <id>` to see current vs cleared balance.
2. Match each transaction against your bank statement.
3. Mark transactions cleared (`"cleared": true`) as you confirm them.
4. When cleared balance equals bank statement balance, reconciliation is complete.
5. Lock the reconciled transactions to prevent changes.

**After reconciliation:** Previously locked transactions can be unlocked individually, reverting to cleared status. Edited locked transactions remain locked.

**Off-budget accounts:** Use reconciliation + "reconciliation transaction" to record asset value changes (property, vehicles, investments).

## Split Transactions

A split transaction has one parent and multiple child transactions.

- `is_parent: true` — the parent row (shows total amount)
- `is_child: true` — individual split lines
- Children reference `parent_id`

**When querying totals:** filter `"is_parent": false` to avoid double-counting. Children represent actual category spending; the parent is a display summary.

## Import vs Add

- `transactions add` — directly inserts transactions; no deduplication
- `transactions import` — runs deduplication against `imported_id`; use `--dry-run` to preview

For automated data pipelines, prefer `import` to avoid duplicates when re-running.
