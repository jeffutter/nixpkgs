#!/usr/bin/env python3
"""
Print actual spending by category for a given month.

Usage:
    python3 spending_by_month.py YYYY-MM
    python3 spending_by_month.py YYYY-MM --skip CAT_ID [CAT_ID ...]
    python3 spending_by_month.py YYYY-MM --json

Output (default): sorted table of category name + amount spent
Output (--json):  raw dict keyed by category ID
"""
import argparse, calendar, json, subprocess, sys
from collections import defaultdict


def run(args):
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"Error: {r.stderr}", file=sys.stderr)
        sys.exit(1)
    return json.loads(r.stdout)


def spending_by_category(month: str, skip: set[str] = None) -> dict:
    skip = skip or set()
    year, mo = month.split("-")
    last_day = calendar.monthrange(int(year), int(mo))[1]
    result = run([
        "actual", "query", "run",
        "--table", "transactions",
        "--select", "category,category.name,amount",
        "--filter", json.dumps({"$and": [
            {"date": {"$gte": f"{month}-01"}},
            {"date": {"$lte": f"{month}-{last_day:02d}"}},
            {"is_parent": False},
            {"category": {"$ne": None}},
        ]}),
        "--format", "json",
    ])
    totals = defaultdict(lambda: {"name": "", "amount": 0})
    for t in result["data"]:
        cid = t["category"]
        if cid in skip:
            continue
        totals[cid]["name"] = t.get("category.name", "")
        totals[cid]["amount"] += t["amount"]
    return {
        cid: {"name": info["name"], "amount": -info["amount"]}
        for cid, info in totals.items()
        if info["amount"] < 0
    }


def main():
    parser = argparse.ArgumentParser(description="Show spending by category for a month.")
    parser.add_argument("month", help="Month in YYYY-MM format")
    parser.add_argument("--skip", nargs="*", metavar="CAT_ID", default=[], help="Category IDs to exclude")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    args = parser.parse_args()

    data = spending_by_category(args.month, skip=set(args.skip))

    if args.json:
        print(json.dumps(data, indent=2))
        return

    total = sum(v["amount"] for v in data.values())
    print(f"\nSpending for {args.month}")
    print("-" * 50)
    for cid, info in sorted(data.items(), key=lambda x: -x[1]["amount"]):
        print(f"  {info['name']:<35}  ${info['amount']/100:>8.2f}")
    print("-" * 50)
    print(f"  {'TOTAL':<35}  ${total/100:>8.2f}")


if __name__ == "__main__":
    main()
