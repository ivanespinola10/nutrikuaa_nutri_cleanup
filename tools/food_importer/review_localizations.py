#!/usr/bin/env python3
"""Validate editorial food names and household measures against a fixed catalog.

This command is offline and deliberately does not update the distributed DB.
Only reviewed output from the exact source release may be used in a later
versioned catalog build.
"""

import argparse
import csv
import json
import math
import sqlite3
from datetime import date
from pathlib import Path

FIELDS = (
    "source_food_id", "source_release", "original_name", "locale",
    "localized_name", "measure_name", "measure_grams", "reviewer",
    "review_date", "evidence",
)


def validate(catalog: Path, submissions: Path) -> list[dict]:
    entries = []
    seen = set()
    with sqlite3.connect(f"file:{catalog.resolve()}?mode=ro", uri=True) as db:
        with submissions.open(encoding="utf-8-sig", newline="") as source:
            rows = csv.DictReader(source)
            if rows.fieldnames != list(FIELDS):
                raise ValueError(f"CSV columns must be: {', '.join(FIELDS)}")
            for line, row in enumerate(rows, start=2):
                if None in row or any(value is None for value in row.values()):
                    raise ValueError(f"Line {line}: malformed row")
                row = {key: value.strip() for key, value in row.items()}
                required = ("source_food_id", "source_release", "original_name",
                            "locale", "localized_name", "reviewer", "review_date",
                            "evidence")
                if any(not row[key] for key in required):
                    raise ValueError(f"Line {line}: missing identity or review evidence")
                if row["locale"] not in ("es-PY",):
                    raise ValueError(f"Line {line}: locale is not approved for this release")
                try:
                    review_date = date.fromisoformat(row["review_date"])
                except ValueError as error:
                    raise ValueError(f"Line {line}: invalid review date") from error
                if review_date > date.today():
                    raise ValueError(f"Line {line}: review date is in the future")
                measure = row["measure_name"]
                weight = row["measure_grams"]
                if bool(measure) != bool(weight):
                    raise ValueError(f"Line {line}: measure and grams must be paired")
                if weight:
                    try:
                        grams = float(weight)
                    except ValueError as error:
                        raise ValueError(f"Line {line}: invalid measure grams") from error
                    if not math.isfinite(grams) or grams <= 0:
                        raise ValueError(f"Line {line}: measure grams must be positive")
                    row["measure_grams"] = grams
                else:
                    row["measure_grams"] = None
                found = db.execute(
                    "SELECT name, source_release FROM foods WHERE source_food_id = ?",
                    (row["source_food_id"],),
                ).fetchone()
                if found != (row["original_name"], row["source_release"]):
                    raise ValueError(f"Line {line}: food identity or release mismatch")
                key = (row["source_food_id"], row["locale"], measure.casefold())
                if key in seen:
                    raise ValueError(f"Line {line}: duplicated food/locale/measure")
                seen.add(key)
                entries.append(row)
    return sorted(entries, key=lambda row: (row["source_food_id"], row["measure_name"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", required=True, type=Path)
    parser.add_argument("--submissions", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    entries = validate(args.catalog, args.submissions)
    # An empty or failed review never silently replaces an existing release.
    if not entries:
        raise ValueError("No reviewed entries; no release was created")
    payload = {"schema_version": 1, "entries": entries}
    args.output.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8",
    )
    print(f"Validated {len(entries)} editorial rows from {args.catalog}")


if __name__ == "__main__":
    main()
