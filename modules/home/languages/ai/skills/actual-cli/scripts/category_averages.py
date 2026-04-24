#!/usr/bin/env python3
"""
Compute average, min, and max spending per category across a list of complete months.
Useful for setting forward-looking budget targets.

Usage:
    python3 category_averages.py YYYY-MM [YYYY-MM ...]
    python3 category_averages.py YYYY-MM [YYYY-MM ...] --skip CAT_ID [CAT_ID ...]
    python3 category_averages.py YYYY-MM [YYYY-MM ...] --json

Output (default): table with avg/min/max per category
Output (--json):  raw dict keyed by category ID
"""
import argparse, json, sys
from collections import defaultdict

# Import sibling script's core function
import importlib.util, pathlib
_spec = importlib.util.spec_from_file_location(
    "spending_by_month",
    pathlib.Path(__file__).parent / "spending_by_month.py"
)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)
spending_by_category = _mod.spending_by_category


def category_averages(months: list[str], skip: set[str] = None) -> dict:
    skip = skip or set()
    n = len(months)
    by_cat = defaultdict(lambda: {"name": "", "values": []})

    for month in months:
        for cid, info in spending_by_category(month, skip=skip).items():
            by_cat[cid]["name"] = info["name"]
            by_cat[cid]["values"].append(info["amount"])

    return {
        cid: {
            "name":   info["name"],
            "avg":    sum(info["values"]) / n,
            "min":    min(info["values"] + [0] * (n - len(info["values"]))),
            "max":    max(info["values"]),
            "values": info["values"],
            "months_present": len(info["values"]),
            "months_total":   n,
        }
        for cid, info in by_cat.items()
    }


def main():
    parser = argparse.ArgumentParser(description="Average spending per category across months.")
    parser.add_argument("months", nargs="+", help="Months in YYYY-MM format (complete months only)")
    parser.add_argument("--skip", nargs="*", metavar="CAT_ID", default=[], help="Category IDs to exclude")
    parser.add_argument("--json", action="store_true", help="Output raw JSON")
    args = parser.parse_args()

    data = category_averages(args.months, skip=set(args.skip))

    if args.json:
        print(json.dumps(data, indent=2))
        return

    print(f"\nCategory averages across {len(args.months)} months: {', '.join(args.months)}")
    print(f"{'Category':<35}  {'Avg':>8}  {'Min':>8}  {'Max':>8}  Present")
    print("-" * 80)
    for cid, info in sorted(data.items(), key=lambda x: -x[1]["avg"]):
        present = f"{info['months_present']}/{info['months_total']}"
        print(
            f"  {info['name']:<35}"
            f"  ${info['avg']/100:>7.0f}"
            f"  ${info['min']/100:>7.0f}"
            f"  ${info['max']/100:>7.0f}"
            f"  {present}"
        )


if __name__ == "__main__":
    main()
