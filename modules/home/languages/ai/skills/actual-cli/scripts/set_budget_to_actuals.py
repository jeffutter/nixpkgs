#!/usr/bin/env python3
"""
Set each expense category's budget amount to match actual spending for one or more months.

Usage:
    python3 set_budget_to_actuals.py YYYY-MM
    python3 set_budget_to_actuals.py YYYY-MM [YYYY-MM ...]
    python3 set_budget_to_actuals.py YYYY-MM --skip CAT_ID [CAT_ID ...]
    python3 set_budget_to_actuals.py YYYY-MM --zero CAT_ID [CAT_ID ...]
    python3 set_budget_to_actuals.py YYYY-MM --dry-run

Options:
    --skip   Category IDs to leave untouched entirely (e.g. income categories)
    --zero   Category IDs to explicitly set to $0 (e.g. categories whose transactions
             were converted to transfers)
    --dry-run  Print what would be set without making any changes
"""
import argparse, json, subprocess, sys

import importlib.util, pathlib
_spec = importlib.util.spec_from_file_location(
    "spending_by_month",
    pathlib.Path(__file__).parent / "spending_by_month.py"
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
spending_by_category = _mod.spending_by_category


def run(args):
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"Error: {r.stderr}", file=sys.stderr)
        sys.exit(1)
    return json.loads(r.stdout)


def set_budget_to_actuals(month: str, skip: set[str], zero: set[str], dry_run: bool):
    label = "[DRY RUN] " if dry_run else ""
    print(f"\n{label}=== {month} ===")

    for cid in zero:
        print(f"  {label}ZERO  (explicit zero for {cid})")
        if not dry_run:
            run(["actual", "budgets", "set-amount",
                 "--month", month, "--category", cid, "--amount", "0"])

    for cid, info in sorted(spending_by_category(month, skip=skip | zero).items(),
                            key=lambda x: x[1]["name"]):
        amt = info["amount"]
        print(f"  {label}SET   {info['name']:<35}  ${amt/100:.2f}")
        if not dry_run:
            run(["actual", "budgets", "set-amount",
                 "--month", month, "--category", cid, "--amount", str(amt)])


def main():
    parser = argparse.ArgumentParser(description="Set budget amounts to match actual spending.")
    parser.add_argument("months", nargs="+", help="One or more months in YYYY-MM format")
    parser.add_argument("--skip", nargs="*", metavar="CAT_ID", default=[],
                        help="Category IDs to leave untouched")
    parser.add_argument("--zero", nargs="*", metavar="CAT_ID", default=[],
                        help="Category IDs to explicitly set to $0")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print changes without applying them")
    args = parser.parse_args()

    for month in args.months:
        set_budget_to_actuals(
            month,
            skip=set(args.skip),
            zero=set(args.zero),
            dry_run=args.dry_run,
        )

    if not args.dry_run:
        print("\nDone.")


if __name__ == "__main__":
    main()
