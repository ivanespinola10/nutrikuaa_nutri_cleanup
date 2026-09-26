import csv
import sqlite3
import tempfile
import unittest
from pathlib import Path

from review_localizations import FIELDS, validate


class EditorialGateTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.catalog = self.root / "foods.db"
        self.csv = self.root / "reviews.csv"
        with sqlite3.connect(self.catalog) as db:
            db.execute("CREATE TABLE foods (source_food_id TEXT, name TEXT, source_release TEXT)")
            db.execute("INSERT INTO foods VALUES ('101', 'Plain yogurt', 'FDC-1')")

    def submit(self, **changes):
        row = dict(zip(FIELDS, (
            '101', 'FDC-1', 'Plain yogurt', 'es-PY', 'Yogur natural',
            'taza (medida comprobada)', '240', 'Profesional revisor',
            '2026-01-12', 'Ficha de medición local identificada',
        )))
        row.update(changes)
        with self.csv.open('w', encoding='utf-8', newline='') as destination:
            writer = csv.DictWriter(destination, fieldnames=FIELDS)
            writer.writeheader()
            writer.writerow(row)

    def test_verified_name_and_measure_keep_original_source(self):
        self.submit()
        entry, = validate(self.catalog, self.csv)
        self.assertEqual(entry['source_food_id'], '101')
        self.assertEqual(entry['original_name'], 'Plain yogurt')
        self.assertEqual(entry['measure_grams'], 240)

    def test_stale_release_or_unmeasured_portion_is_rejected(self):
        for changes in ({'source_release': 'FDC-2'},
                        {'measure_grams': ''},
                        {'measure_grams': 'nan'}):
            with self.subTest(changes=changes):
                self.submit(**changes)
                with self.assertRaises(ValueError):
                    validate(self.catalog, self.csv)


if __name__ == '__main__':
    unittest.main()
