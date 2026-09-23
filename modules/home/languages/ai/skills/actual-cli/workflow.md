# Budget workflow

Read this file when setting up a budget, running the monthly cycle, or fixing To Budget.

## Initial setup

1. Pull the last 3 to 6 months of transactions to find spending patterns.
2. Create few categories. Splitting one later is easier than merging many.
3. Allocate the current balance across categories until To Budget is 0.
4. Adjust amounts after one month of real tracking.

## Category structure

- Essential/Fixed: rent, utilities, insurance, property taxes.
- Debt: mortgage, loans, credit card minimums.
- Daily Spending: groceries, fuel, entertainment, subscriptions.
- Emergency Reserves: emergency fund, unexpected costs.
- Savings Goals: short-term goals as on-budget categories. Put retirement in off-budget accounts.
- Income: one group only. A budget allows exactly one income group.

## Monthly cycle

1. When income arrives, allocate it until To Budget is 0.
2. During the month, import and categorize transactions. Create rules for repeat payees.
3. When a category goes negative, move funds from a surplus category.
4. At month end, review category balances. Positive balances roll forward.
5. Open next month. Copy last month's amounts when spending is stable. Set amounts to 0 when patterns changed.

## Fixing To Budget

- Positive To Budget is unassigned income. Assign it to categories.
- Negative To Budget means allocations exceed income. Reduce allocations or draw from a savings category.
- Deficit month: set a savings category's budget to minus the deficit. A $500 deficit becomes `--amount -50000` on "Emergency Fund".
- Historical month with positive To Budget: run `actual budgets hold-next-month --month YYYY-MM --amount <toBudget-cents>`. The held amount still flows into the next month.
- Assigning a historical surplus to a savings category breaks later months, because month M+1 loses its carried-in amount. Use `hold-next-month` instead.
- Undo a hold with `actual budgets reset-hold --month YYYY-MM`.

## Category maintenance

- Hide inactive categories with `categories update <id> --hidden true`. Hidden categories still count in budget math.
- Deleting a category requires `--transfer-to <id>` to reassign its transactions.
- Category notes support Markdown. Record the category's scope, spending limit, and savings target there.
