#!/usr/bin/env python3
"""
Build a versioned, read-only NutriKuaa food catalog from an already-downloaded
USDA FoodData Central CSV export.

This tool intentionally performs NO network requests and NO web scraping.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, Iterable, Optional


SCHEMA_VERSION = 1
# Specific food factors are preferred when several USDA energy methods exist.
# Keep the selected USDA nutrient ID in the catalog for auditability.
ENERGY_SOURCE_PRIORITY = {"2048": 0, "2047": 1, "1008": 2}


def normalize(text: Optional[str]) -> str:
    return " ".join((text or "").strip().lower().split())


def detect_text_encoding(path: Path) -> str:
    """Prefer UTF-8 when valid, otherwise fall back to ISO-8859-1.

    FoodData Central documentation historically describes downloadable ASCII
    files using ISO-8859-1, while newer exports may be UTF-8 compatible.
    Detection is intentionally local and deterministic.
    """
    with path.open("rb") as handle:
        sample = handle.read(1024 * 1024)

    if sample.startswith(b"\xef\xbb\xbf"):
        return "utf-8-sig"

    try:
        sample.decode("utf-8")
        return "utf-8"
    except UnicodeDecodeError:
        return "latin-1"


def open_csv(path: Path):
    return path.open(
        "r",
        encoding=detect_text_encoding(path),
        newline="",
    )


def require_files(input_dir: Path, names: Iterable[str]) -> Dict[str, Path]:
    result: Dict[str, Path] = {}
    missing = []

    for name in names:
        path = input_dir / name
        if path.exists():
            result[name] = path
        else:
            missing.append(name)

    if missing:
        raise FileNotFoundError(
            "Missing required FoodData Central file(s): " + ", ".join(missing)
        )

    return result


def optional_file(input_dir: Path, name: str) -> Optional[Path]:
    path = input_dir / name
    return path if path.exists() else None


def load_mapping(path: Path):
    data = json.loads(path.read_text(encoding="utf-8"))
    by_id = {}
    by_name = {}

    for item in data["mappings"]:
        normalized_item = {
            "code": item["code"],
            "unit": item["unit"],
            "source_units": {normalize(v) for v in item.get("source_units", [])},
        }

        for nutrient_id in item.get("usda_ids", []):
            by_id[str(nutrient_id)] = normalized_item

        for alias in item.get("aliases", []):
            by_name[normalize(alias)] = normalized_item

    return by_id, by_name


def find_column(fieldnames, *candidates: str) -> str:
    lookup = {normalize(name): name for name in (fieldnames or [])}

    for candidate in candidates:
        resolved = lookup.get(normalize(candidate))
        if resolved:
            return resolved

    raise ValueError(
        f"CSV schema changed: none of these columns were found: {candidates}. "
        f"Available columns: {fieldnames}"
    )


def create_schema(conn: sqlite3.Connection):
    conn.executescript(
        """
        PRAGMA journal_mode = DELETE;
        PRAGMA foreign_keys = ON;

        CREATE TABLE catalog_metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        );

        CREATE TABLE foods (
          id INTEGER PRIMARY KEY,
          source_food_id TEXT NOT NULL UNIQUE,
          name TEXT NOT NULL,
          data_type TEXT,
          category_id TEXT,
          publication_date TEXT,
          source_name TEXT NOT NULL,
          source_release TEXT NOT NULL
        );

        CREATE TABLE food_nutrients (
          food_id INTEGER NOT NULL,
          nutrient_code TEXT NOT NULL,
          value_per_100g REAL NOT NULL,
          unit TEXT NOT NULL,
          source_nutrient_id TEXT,
          PRIMARY KEY (food_id, nutrient_code),
          FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
        );

        CREATE TABLE food_portions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          food_id INTEGER NOT NULL,
          amount REAL,
          measure TEXT,
          gram_weight REAL NOT NULL,
          modifier TEXT,
          sequence INTEGER,
          FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
        );

        CREATE INDEX idx_foods_name
          ON foods(name COLLATE NOCASE);

        CREATE INDEX idx_foods_data_type
          ON foods(data_type);

        CREATE INDEX idx_food_nutrients_food
          ON food_nutrients(food_id);

        CREATE INDEX idx_food_portions_food
          ON food_portions(food_id);
        """
    )


def import_nutrient_reference(
    nutrient_path: Path,
    mapping_path: Path,
):
    by_id, by_name = load_mapping(mapping_path)
    resolved = {}

    with open_csv(nutrient_path) as handle:
        reader = csv.DictReader(handle)
        id_col = find_column(reader.fieldnames, "id", "nutrient_id")
        name_col = find_column(reader.fieldnames, "name", "nutrient_name")
        unit_col = find_column(reader.fieldnames, "unit_name", "unit")

        for row in reader:
            nutrient_id = str(row[id_col]).strip()
            nutrient_name = normalize(row[name_col])
            source_unit = normalize(row[unit_col])

            target = by_id.get(nutrient_id) or by_name.get(nutrient_name)
            if not target:
                continue

            accepted_units = target["source_units"]
            if accepted_units and source_unit not in accepted_units:
                continue

            resolved[nutrient_id] = target

    return resolved


def import_foods(
    conn: sqlite3.Connection,
    food_path: Path,
    source_name: str,
    source_release: str,
    allowed_data_types,
):
    inserted = 0

    with open_csv(food_path) as handle:
        reader = csv.DictReader(handle)
        fdc_col = find_column(reader.fieldnames, "fdc_id")
        name_col = find_column(reader.fieldnames, "description", "name")
        type_col = find_column(reader.fieldnames, "data_type")
        category_col = None
        publication_col = None

        try:
            category_col = find_column(reader.fieldnames, "food_category_id")
        except ValueError:
            pass

        try:
            publication_col = find_column(reader.fieldnames, "publication_date")
        except ValueError:
            pass

        rows = []
        for row in reader:
            data_type = (row.get(type_col) or "").strip()

            if allowed_data_types and normalize(data_type) not in allowed_data_types:
                continue

            rows.append(
                (
                    int(row[fdc_col]),
                    str(row[fdc_col]).strip(),
                    (row[name_col] or "").strip(),
                    data_type or None,
                    (row.get(category_col) or "").strip() or None
                    if category_col
                    else None,
                    (row.get(publication_col) or "").strip() or None
                    if publication_col
                    else None,
                    source_name,
                    source_release,
                )
            )

            if len(rows) >= 5000:
                conn.executemany(
                    """
                    INSERT INTO foods (
                      id, source_food_id, name, data_type, category_id,
                      publication_date, source_name, source_release
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    rows,
                )
                inserted += len(rows)
                rows.clear()

        if rows:
            conn.executemany(
                """
                INSERT INTO foods (
                  id, source_food_id, name, data_type, category_id,
                  publication_date, source_name, source_release
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                rows,
            )
            inserted += len(rows)

    return inserted


def import_food_nutrients(
    conn: sqlite3.Connection,
    food_nutrient_path: Path,
    nutrient_map,
):
    existing_food_ids = {
        row[0] for row in conn.execute("SELECT id FROM foods")
    }
    selected = {}

    with open_csv(food_nutrient_path) as handle:
        reader = csv.DictReader(handle)
        fdc_col = find_column(reader.fieldnames, "fdc_id")
        nutrient_col = find_column(reader.fieldnames, "nutrient_id")
        amount_col = find_column(reader.fieldnames, "amount")

        for row in reader:
            try:
                food_id = int(row[fdc_col])
            except (TypeError, ValueError):
                continue

            if food_id not in existing_food_ids:
                continue

            source_nutrient_id = str(row[nutrient_col]).strip()
            target = nutrient_map.get(source_nutrient_id)
            if not target:
                continue

            try:
                amount = float(row[amount_col])
            except (TypeError, ValueError):
                continue
            if not math.isfinite(amount) or amount < 0:
                continue

            key = (food_id, target["code"])
            rank = (
                ENERGY_SOURCE_PRIORITY.get(source_nutrient_id, 999)
                if target["code"] == "energy_kcal"
                else 0
            )
            previous = selected.get(key)
            if previous is None or rank < previous[0]:
                selected[key] = (
                    rank,
                    food_id,
                    target["code"],
                    amount,
                    target["unit"],
                    source_nutrient_id,
                )

    conn.executemany(
        """
        INSERT INTO food_nutrients (
          food_id, nutrient_code, value_per_100g, unit, source_nutrient_id
        ) VALUES (?, ?, ?, ?, ?)
        """,
        (values[1:] for values in selected.values()),
    )
    return len(selected)


def load_measure_units(measure_unit_path: Optional[Path]):
    if not measure_unit_path:
        return {}

    result = {}
    with open_csv(measure_unit_path) as handle:
        reader = csv.DictReader(handle)
        id_col = find_column(reader.fieldnames, "id")
        name_col = find_column(reader.fieldnames, "name")

        for row in reader:
            result[str(row[id_col]).strip()] = (row[name_col] or "").strip()

    return result


def import_portions(
    conn: sqlite3.Connection,
    portion_path: Optional[Path],
    measure_unit_path: Optional[Path],
):
    if not portion_path:
        return 0

    existing_food_ids = {
        row[0] for row in conn.execute("SELECT id FROM foods")
    }
    measure_units = load_measure_units(measure_unit_path)
    imported = 0

    with open_csv(portion_path) as handle:
        reader = csv.DictReader(handle)
        fdc_col = find_column(reader.fieldnames, "fdc_id")
        gram_col = find_column(reader.fieldnames, "gram_weight")

        def optional_column(*names):
            try:
                return find_column(reader.fieldnames, *names)
            except ValueError:
                return None

        amount_col = optional_column("amount")
        measure_col = optional_column("measure_unit_id")
        desc_col = optional_column("portion_description")
        modifier_col = optional_column("modifier")
        seq_col = optional_column("seq_num", "sequence")

        rows = []
        for row in reader:
            try:
                food_id = int(row[fdc_col])
                gram_weight = float(row[gram_col])
            except (TypeError, ValueError):
                continue

            if food_id not in existing_food_ids or gram_weight <= 0:
                continue

            amount = None
            if amount_col:
                try:
                    amount = float(row[amount_col])
                except (TypeError, ValueError):
                    pass

            measure = None
            if desc_col and (row.get(desc_col) or "").strip():
                measure = (row.get(desc_col) or "").strip()
            elif measure_col:
                measure = measure_units.get(str(row.get(measure_col) or "").strip())

            modifier = (
                (row.get(modifier_col) or "").strip() or None
                if modifier_col
                else None
            )

            sequence = None
            if seq_col:
                try:
                    sequence = int(float(row[seq_col]))
                except (TypeError, ValueError):
                    pass

            rows.append(
                (
                    food_id,
                    amount,
                    measure,
                    gram_weight,
                    modifier,
                    sequence,
                )
            )

            if len(rows) >= 10000:
                conn.executemany(
                    """
                    INSERT INTO food_portions (
                      food_id, amount, measure, gram_weight, modifier, sequence
                    ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    rows,
                )
                imported += len(rows)
                rows.clear()

        if rows:
            conn.executemany(
                """
                INSERT INTO food_portions (
                  food_id, amount, measure, gram_weight, modifier, sequence
                ) VALUES (?, ?, ?, ?, ?, ?)
                """,
                rows,
            )
            imported += len(rows)

    return imported


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_metadata(conn: sqlite3.Connection, values):
    conn.executemany(
        "INSERT INTO catalog_metadata(key, value) VALUES (?, ?)",
        list(values.items()),
    )


def parse_args():
    parser = argparse.ArgumentParser(
        description="Build NutriKuaa's fixed food catalog from local USDA CSV files."
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--source-release", required=True)
    parser.add_argument(
        "--source-name",
        default="USDA FoodData Central",
    )
    parser.add_argument(
        "--mapping",
        type=Path,
        default=Path(__file__).with_name("nutrient_mapping.json"),
    )
    parser.add_argument(
        "--data-type",
        action="append",
        default=[],
        help=(
            "Optional FoodData Central data_type filter. "
            "May be specified more than once."
        ),
    )
    return parser.parse_args()


def main():
    args = parse_args()
    input_dir = args.input.resolve()
    output = args.output.resolve()
    mapping_path = args.mapping.resolve()

    required = require_files(
        input_dir,
        ["food.csv", "nutrient.csv", "food_nutrient.csv"],
    )
    portion_path = optional_file(input_dir, "food_portion.csv")
    measure_unit_path = optional_file(input_dir, "measure_unit.csv")

    if not mapping_path.exists():
        raise FileNotFoundError(f"Nutrient mapping not found: {mapping_path}")

    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    allowed_data_types = {normalize(v) for v in args.data_type}
    nutrient_map = import_nutrient_reference(
        required["nutrient.csv"],
        mapping_path,
    )

    if not nutrient_map:
        raise RuntimeError(
            "No nutrients could be mapped. Review nutrient_mapping.json "
            "or the FoodData Central nutrient.csv schema."
        )

    conn = sqlite3.connect(output)

    try:
        create_schema(conn)

        food_count = import_foods(
            conn,
            required["food.csv"],
            args.source_name,
            args.source_release,
            allowed_data_types,
        )

        nutrient_count = import_food_nutrients(
            conn,
            required["food_nutrient.csv"],
            nutrient_map,
        )

        portion_count = import_portions(
            conn,
            portion_path,
            measure_unit_path,
        )

        write_metadata(
            conn,
            {
                "schema_version": str(SCHEMA_VERSION),
                "source_name": args.source_name,
                "source_release": args.source_release,
                "food_count": str(food_count),
                "nutrient_value_count": str(nutrient_count),
                "portion_count": str(portion_count),
            },
        )

        conn.commit()
        conn.execute("PRAGMA optimize")
        conn.execute("VACUUM")
    finally:
        conn.close()

    checksum = sha256_file(output)
    manifest = {
        "schemaVersion": SCHEMA_VERSION,
        "dataVersion": args.source_release,
        "sourceName": args.source_name,
        "sourceRelease": args.source_release,
        "databaseFile": output.name,
        "sha256": checksum,
        "builtAtUtc": datetime.now(timezone.utc).isoformat(),
        "networkRequiredAtRuntime": False,
    }

    manifest_path = Path(str(output) + ".manifest.json")
    manifest_path.write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print(f"Created: {output}")
    print(f"Manifest: {manifest_path}")
    print(f"SHA-256: {checksum}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        sys.exit(1)
