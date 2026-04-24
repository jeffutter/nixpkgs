# Budget Management Workflow

## Initial Setup

1. Pull 3–6 months of bank statements to identify spending patterns (don't go further back — old data distorts averages).
2. Start with fewer categories. It's easier to split one category later than to merge many.
3. Allocate your current balance across categories until "To Budget" = 0.
4. Don't overthink initial amounts — adjust after a month of real tracking.

## Recommended Category Structure

| Group | Contents |
|-------|----------|
| Essential/Fixed | Rent, utilities, insurance, property taxes |
| Debt | Mortgage, loans, credit card minimums |
| Daily Spending | Groceries, fuel, entertainment, subscriptions |
| Emergency Reserves | Emergency fund, unexpected costs |
| Savings Goals | Short-term targets (on-budget); long-term retirement (off-budget) |

Keep one income group. Only one income group is permitted per budget.

## Monthly Cycle

```
Start of month
  → Receive income → allocate to categories until To Budget = 0
  
During month
  → Import/categorize transactions regularly
  → When category goes negative → move funds from surplus categories
  → Log every transaction; use rules to automate categorization
  
End of month
  → Review category balances
  → Positive balances roll forward automatically
  → Decide: hold surplus for next month vs. leave in categories
  → Open next month → copy or adjust prior month's allocations
```

## Building Next Month's Budget

Options when opening a new month:
- **Copy last month** — good when spending is stable.
- **Set to zero** — good when patterns changed significantly.
- **Use templates/goals** — automate target allocations for savings and fixed expenses.

## Savings Categories (On-Budget)

For short-term goals (vacation, car repair fund, appliance replacement), create a dedicated on-budget category and allocate monthly. The balance accumulates. Spending from it reduces the balance directly.

For long-term retirement savings, use off-budget accounts so they don't inflate your day-to-day available funds.

## "To Budget" Management

- **Positive To Budget** = income received but not yet assigned. Assign it before spending.
- **Negative To Budget** = you've allocated more than you have this month. Either reduce category allocations or explicitly draw from a savings category (see below).
- Never budget against money you haven't received.

**Deficit months (income < expenses):** When a month's income doesn't fully cover what you've budgeted, cover the gap by setting a savings category's budget to a negative amount equal to the deficit. This brings "To Budget" to zero and explicitly records which savings funded the shortfall. Example: deficit of $500 → set "Emergency Fund" budget to `-50000` cents for that month.

**Cleaning up historical months with positive "To Budget":** Do NOT assign the surplus to a Savings category — this causes cascade failures because zeroing month M removes the `fromLastMonth` that month M+1 was counting on. Instead, use `budgets hold-next-month` for each month. This zeroes the month's "To Budget" display while keeping the cascade intact (the held amount still flows to the next month as `fromLastMonth`).

```bash
# Zero out a historical month's To Budget without breaking the cascade
actual budgets hold-next-month --month 2025-11 --amount <toBudget-in-cents>

# Undo a hold
actual budgets reset-hold --month 2025-11
```

**"To Budget" and category moves are independent:** Moving money between two categories (increase one, decrease the other by the same amount) has zero net effect on "To Budget". Only changing the *total* of all category allocations moves "To Budget".

## Category Visibility

Hidden categories still affect budget calculations — they just don't clutter the view. Use hiding for inactive seasonal categories rather than deleting them (deletion requires reassigning transaction history).

## Category Notes

Actual supports Markdown notes on categories. Use them to document:
- Spending rules ("max $X/month on dining out")
- What the category covers
- Accumulation targets for sinking funds
