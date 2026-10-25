# NutriKuaa Nutri — Testing Plan

## Backend milestone before UI migration

The backend foundation is considered ready for UI integration only when all of
the following are true:

- Flutter static analysis has no errors.
- Unit tests pass.
- The SQLite end-to-end backend flow passes on desktop.
- The offline USDA catalog builder smoke test passes.
- Professional foods and official catalog foods can be searched together.
- An official food can be materialized once into the private database.
- Source name, source id, source release, nutrients and portions survive the snapshot.
- Patients and nutrition targets persist correctly.
- Recipes persist and can be duplicated.
- Multi-day meal plans persist and can be duplicated.
- Daily nutritional totals are calculated from foods and recipes.
- No test requires Internet access.

## Automated GitHub test environment

Pull requests and pushes to main run:

```text
flutter pub get
flutter analyze
flutter test
python3 tools/food_importer/test_import_usda.py
```

Workflow:

```text
.github/workflows/ci.yml
```

## Local Windows test environment

When preparing a developer machine:

```powershell
git checkout feature/nutri-backend-foundation
flutter doctor
flutter pub get
flutter analyze
flutter test
python tools/food_importer/test_import_usda.py
```

The desktop SQLite test layer uses `sqflite_common_ffi` only as a development
dependency. The production application continues to use its normal SQLite
implementation.

## Official catalog test

The application does not download FoodData Central.

For an official dataset validation:

1. Download and extract the selected FoodData Central CSV release manually.
2. Run the importer against that local folder, for example:

```powershell
python tools/food_importer/import_usda.py --input "D:\datasets\FDC_RELEASE" --output "build\nutrikuaa_foods.db" --source-release "USDA FoodData Central YYYY-MM"
```

3. Review the generated manifest and counts.
4. Open/query the generated database locally.
5. Only after review, copy the approved database into `assets/data/` and set
   its manifest to `bundled: true`.

## Test data policy

Fake/sample catalog records are allowed in automated tests only.

A development fixture must never be published as an official NutriKuaa food
catalog.

## Web license test (Lemon Squeezy test mode)

1. Open **Settings → Professional license** and use **Buy license** to open
   the configured Lemon Squeezy checkout.
2. Complete a test-mode purchase and copy the generated license key from the
   test order.
3. Return to Nutrikuaa, enter the key and choose **Activate license**.
4. Confirm the license status changes to active.
5. Reload the browser and use **Validate license** to confirm the saved
   activation is still valid.
6. Choose **Deactivate in this browser** and confirm the activation is removed.

Without an active license, the preview allows up to one patient, one plan and
one recipe. Existing records can still be edited, and generated PDFs include a
preview notice. Activating a valid license removes these limits and the PDF
notice.

7. With no active license, verify a second patient, plan or recipe is blocked,
   while editing the existing records remains available.
8. Generate a PDF without a license and confirm the preview notice appears;
   activate the license and generate another PDF to confirm it is removed.

## Next phase after this milestone

Once this backend milestone is green:

1. Merge the backend foundation.
2. Create the first reviewed `nutrikuaa_foods.db`.
3. Build the first Nutri UI shell.
4. Connect Patients, Food search, Recipes, Weekly plan builder and real-time nutrient totals.
5. Start manual usability testing with synthetic patients.
6. Only after that, add PDF, Food Swap and mathematical plan optimization.
