# NutriKuaa Food Database Builder

This folder contains **developer-only tooling** for building the official food
database shipped with NutriKuaa Nutri.

## Important rule

The mobile/desktop application does **not** download or scrape USDA/FDA pages
at runtime.

The release workflow is:

1. A maintainer manually downloads an official FoodData Central dataset.
2. The archive is extracted locally.
3. `import_usda.py` converts the official CSV files into NutriKuaa's stable
   SQLite schema.
4. The generated `nutrikuaa_foods.db` and manifest are reviewed.
5. The reviewed database file is bundled with a NutriKuaa release.
6. On application update, the bundled official catalog can replace the
   previous official catalog without touching professional/user data.

This intentionally trades real-time freshness for reproducibility,
professional traceability and low maintenance.

## Why this is safer

FoodData Central can change web pages, download URLs or export formats. None of
those changes can break an installed NutriKuaa application because the
application never depends on the website.

If USDA changes the downloadable CSV schema, only this developer tool may need
an update. Existing NutriKuaa installations remain fully functional with their
bundled catalog.

## Input

The importer expects an **already extracted** FoodData Central CSV export.

Required files:

- `food.csv`
- `nutrient.csv`
- `food_nutrient.csv`

Optional files:

- `food_portion.csv`
- `measure_unit.csv`

The importer deliberately performs no network requests.

## Example

```bash
python tools/food_importer/import_usda.py \
  --input "D:/datasets/FoodData_Central_foundation_food_csv_2026-04-23" \
  --output "build/nutrikuaa_foods.db" \
  --source-release "USDA FoodData Central Foundation Foods 2026-04"
```

The command also creates:

```text
build/nutrikuaa_foods.db.manifest.json
```

## Output model

The generated catalog is read-only and contains:

```text
catalog_metadata
foods
food_nutrients
food_portions
```

User-created foods, branded products entered by a nutrition professional,
patients, recipes and plans do **not** belong in this database.

Those records live in the user's private `nutrikuaa_nutri.db`.

## Update policy

Official catalog updates are versioned releases, not background synchronization.

A food already used in a professional plan should be materialized/snapshotted
into the user's private database so that future official catalog updates do not
silently change historical plans.
