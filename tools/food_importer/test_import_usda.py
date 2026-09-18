import csv
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


HERE = Path(__file__).resolve().parent
IMPORTER = HERE / "import_usda.py"


def write_csv(path: Path, fieldnames, rows):
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


class FoodImporterTest(unittest.TestCase):
    def test_builds_catalog_without_network(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            source.mkdir()
            output = root / "nutrikuaa_foods.db"

            write_csv(
                source / "food.csv",
                [
                    "fdc_id",
                    "data_type",
                    "description",
                    "food_category_id",
                    "publication_date",
                ],
                [
                    {
                        "fdc_id": "123",
                        "data_type": "foundation_food",
                        "description": "Test yogurt",
                        "food_category_id": "1",
                        "publication_date": "2026-04-01",
                    }
                ],
            )

            write_csv(
                source / "nutrient.csv",
                ["id", "name", "unit_name"],
                [
                    {"id": "1003", "name": "Protein", "unit_name": "g"},
                    {"id": "1008", "name": "Energy", "unit_name": "kcal"},
                ],
            )

            write_csv(
                source / "food_nutrient.csv",
                ["id", "fdc_id", "nutrient_id", "amount"],
                [
                    {
                        "id": "1",
                        "fdc_id": "123",
                        "nutrient_id": "1003",
                        "amount": "9.5",
                    },
                    {
                        "id": "2",
                        "fdc_id": "123",
                        "nutrient_id": "1008",
                        "amount": "95",
                    },
                ],
            )

            write_csv(
                source / "food_portion.csv",
                [
                    "fdc_id",
                    "seq_num",
                    "amount",
                    "portion_description",
                    "gram_weight",
                ],
                [
                    {
                        "fdc_id": "123",
                        "seq_num": "1",
                        "amount": "1",
                        "portion_description": "container",
                        "gram_weight": "150",
                    }
                ],
            )

            result = subprocess.run(
                [
                    sys.executable,
                    str(IMPORTER),
                    "--input",
                    str(source),
                    "--output",
                    str(output),
                    "--source-release",
                    "test-release",
                ],
                capture_output=True,
                text=True,
            )

            self.assertEqual(
                result.returncode,
                0,
                msg=result.stdout + "\n" + result.stderr,
            )
            self.assertTrue(output.exists())
            self.assertTrue(Path(str(output) + ".manifest.json").exists())

            conn = sqlite3.connect(output)
            try:
                food = conn.execute(
                    "SELECT source_food_id, name FROM foods"
                ).fetchone()
                self.assertEqual(food, ("123", "Test yogurt"))

                nutrients = dict(
                    conn.execute(
                        """
                        SELECT nutrient_code, value_per_100g
                        FROM food_nutrients
                        WHERE food_id = 123
                        """
                    ).fetchall()
                )
                self.assertEqual(nutrients["protein_g"], 9.5)
                self.assertEqual(nutrients["energy_kcal"], 95.0)

                portion = conn.execute(
                    """
                    SELECT amount, measure, gram_weight
                    FROM food_portions
                    WHERE food_id = 123
                    """
                ).fetchone()
                self.assertEqual(portion, (1.0, "container", 150.0))
            finally:
                conn.close()


if __name__ == "__main__":
    unittest.main()
