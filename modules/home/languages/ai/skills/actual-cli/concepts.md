# Envelope Budgeting Concepts

## The Core Model

Actual uses **zero-sum envelope budgeting**: every dollar you have must be assigned to a category. No unallocated money. Each dollar has exactly one job.

This is *reality-based*, not prediction-based. You never budget money you haven't received. Income is allocated *after* it arrives.

## How Money Flows

```
Income received → "To Budget" pool → Assigned to categories → Spent from categories
```

- **To Budget** is the unassigned pool. Goal: always zero.
- Categories are the "envelopes." Their balances accumulate or deplete as you budget and spend.
- Negative category balance = you spent more than you allocated. Requires conscious reallocation from elsewhere.

## Rollover Behavior

- **Positive category balances** carry forward to next month automatically.
- **Negative category balances** automatically deduct from next month's available funds, forcing you to confront overspending.
- **"Rollover overspending"** flag keeps negatives persistent across months — useful for reimbursables.

## On-Budget vs Off-Budget Accounts

| Type | Budget impact | Categorization |
|------|--------------|----------------|
| On-budget | Balances count toward available funds | Required |
| Off-budget | Not counted | Not possible |

Use on-budget for: checking, savings, credit cards.
Use off-budget for: mortgages, investment accounts, long-term retirement funds.

**Transfers between two on-budget accounts** are neutral — they don't affect your total available funds and are labeled `_Transfer_` with no category.

**Transfers between off-budget and on-budget** behave like regular transactions and **require a category on the on-budget side.** This is a critical distinction: do NOT treat contributions to investment or off-budget savings accounts as category-null transfers — they will appear as uncategorized in the UI. Categorize them (e.g. "Investments" or "Savings") just like any other expense.

## Three Budgeting Strategies

**The Basics** — Fill essential categories (rent, food, utilities) first, then fill the rest.

**Month Ahead** — Save enough to fund next month entirely with this month's income. Eliminates paycheck-to-paycheck stress. Use "Hold for Next Month" to park current income until the calendar flips.

**Pay-Yourself-First** — Immediately allocate a fixed savings percentage (e.g., 20%) when income arrives, before covering any other expenses.

## Category Envelopes Are Not Account-Specific

Category balances represent designations across **all pooled on-budget accounts**, not money sitting in a particular account. A "OnePay Savings" category with a $20k balance doesn't mean $20k is in the OnePay account — it means $20k of your total on-budget pool is earmarked as savings, physically located wherever your balances happen to be.

**Moving money between categories is always neutral for "To Budget."** Increasing one category's budget and decreasing another by the same amount has zero net effect. Only changing the *total* of all allocations moves "To Budget."

**Negative budget amounts are valid.** Setting a category's monthly budget to a negative value draws down its accumulated balance. This is the correct tool for savings-funded deficit months: reduce the savings category budget by the deficit amount to bring "To Budget" to zero.

## Handling Overspending

Overspending is not failure — it's information. When a category goes negative:
1. Find a category with surplus.
2. Move funds to cover the deficit.
3. Treat the reallocation as a deliberate trade-off, not a patch.

The goal is intentional management, not perfection.

## Irregular & Annual Expenses

Divide the annual cost by 12 and allocate that amount monthly. Example: $1,200/year insurance → $100/month. The category accumulates until the bill arrives.
