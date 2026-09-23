# Schedules

Read this file when creating or changing recurring transactions.

Create a schedule for a predictable transaction: bills, paychecks, recurring transfers, or a known one-time expense.

## Matching

- Actual matches an imported transaction to a schedule by date, amount, payee, and category.
- The transaction date must fall within 2 days of the scheduled date. Skip the occurrence manually when it posts outside that window.
- An "approximately" amount matches within 7.5%. Use it for variable bills such as utilities.
- A matched schedule fires its linked payee rules.

## Patterns

A schedule repeats on a calendar date, the last day of the month, weekly, every two weeks, or a custom interval. One schedule can hold several dates.

## Entry mode

- Auto-entry adds the transaction on the scheduled date.
- Manual approval creates a draft for the user to confirm. Use it for variable amounts.

## Commands

```bash
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

Pass `--reset-next-date` when the update changes the date pattern.
