# Envelope budgeting concepts

Read this file when a task needs the budgeting model behind the numbers.

## Money flow

- Income lands in "To Budget". Assign it to categories until To Budget is 0.
- Budget only income already received.
- A category balance is an allocation across all on-budget accounts together. It is not money in one specific account.
- Moving an amount from one category to another leaves To Budget unchanged. Only a change to the total of all allocations moves To Budget.
- A negative monthly budget for a category draws down that category's accumulated balance.
- To cover an overspent category, move funds from a category with a surplus.

## Rollover

- A positive category balance carries into next month.
- A negative category balance reduces next month's available funds.
- The "rollover overspending" flag (`budgets set-carryover`) keeps a negative balance in the category across months. Use it for reimbursable expenses.

## On-budget and off-budget accounts

- On-budget accounts count toward available funds. Their transactions need a category. Use them for checking, savings, and credit cards.
- Off-budget accounts do not count. Their transactions take no category. Use them for mortgages, investments, and retirement funds.
- Transfer rules live in SKILL.md step 6.

## Strategies

- Basics: fund essentials (rent, food, utilities) first, then the rest.
- Month ahead: fund next month from this month's income. Park the income with `budgets hold-next-month`.
- Pay yourself first: allocate a fixed savings percentage, such as 20%, when income arrives.
- Annual expense: budget the annual cost divided by 12 each month. $1,200 per year becomes `10000` per month.
