# Schedules: Recurring Transactions

## When to Use Schedules

Schedules are best for transactions you can predict:
- Regular bills (rent, utilities, subscriptions)
- Recurring income (paychecks, transfers)
- Anticipated one-time expenses
- Bills with variable amounts (usage-based utilities)

## How Schedules Work

Schedules define a pattern (date + amount + payee + category). When a real transaction arrives from bank sync or import, Actual matches it to the schedule automatically.

**Matching window:** The transaction must be dated within ±2 days of the scheduled date to auto-match. If the actual posting date falls outside this window, skip the upcoming occurrence manually.

**Approximate amounts:** Mark a schedule as "approximately" to match transactions within ±7.5% of the scheduled amount — useful for variable bills.

## Recurring Patterns

- Specific calendar date (e.g., 1st of month, 15th)
- Weekly, bi-weekly, or custom intervals
- Multiple dates within a single schedule
- Last day of month

## Automation Options

**Auto-entry:** Transaction is automatically added to the account register on the scheduled date without manual approval.

**Manual approval:** Actual creates the transaction as a draft; you confirm before it's recorded. Better for variable amounts or when you want review.

## Managing Schedules

```bash
actual schedules list
actual schedules create --data '{
  "name": "Rent",
  "payee_id": "<id>",
  "account": "<id>",
  "category": "<id>",
  "amount": -150000,
  "date": {"start": "2026-01-01", "frequency": "monthly", "patterns": [{"type": "dom", "value": 1}]}
}'
actual schedules update <id> --data '{...}' [--reset-next-date]
actual schedules delete <id>
```

Use `--reset-next-date` when updating a schedule whose next occurrence date needs recalculation from the new pattern.

## Integration with Rules

Schedules can link to payee rules for automatic categorization and note-adding. When a schedule matches a transaction, associated rules fire to clean up the payee name and assign the category.

## Detecting Existing Schedules

Use the "Find schedules" feature (via `actual server bank-sync` after initial import) to automatically detect recurring patterns across your transaction history, rather than creating schedules manually.
