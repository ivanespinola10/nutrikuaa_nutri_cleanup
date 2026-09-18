# Chrome MVP V0.1

This milestone validates the Nutrikuaa Nutri backend inside Flutter Web before
the production USDA catalog is connected to the browser UI.

## What the browser test exercises

The screen uses the real application services and the local SQLite schema:

1. Create a patient.
2. Persist energy and protein targets.
3. Create a branded or professional food.
4. Select patient + food + grams.
5. Create a plan.
6. Create the first meal.
7. Persist the meal item.
8. Read the plan back from SQLite.
9. Calculate energy, protein, carbohydrate and fat totals.
10. Compare energy/protein with the saved target.

The "Cargar datos demo" button creates a reusable demo patient and yogurt so
the first smoke test can be completed with two clicks.

## Browser persistence

Chrome uses `sqflite_common_ffi_web`, backed by SQLite WASM and browser
IndexedDB.

Keep the same debug port between sessions so Chrome reuses the same browser
storage origin.

Recommended port:

```text
8080
```

## One-time Windows preparation

From the repository root:

```powershell
git fetch origin
git checkout feature/nutri-backend-foundation
git pull
.\scripts\prepare_chrome.ps1
```

The script runs:

```text
flutter pub get
dart run sqflite_common_ffi_web:setup --force
flutter analyze --no-fatal-infos --no-fatal-warnings
```

The setup command creates the web SQLite runtime files required by the browser:

- `web/sqlite3.wasm`
- `web/sqflite_sw.js`

## Run in Chrome

```powershell
flutter run -d chrome --web-port 8080
```

## Fast acceptance test

1. Confirm the top badge says that local SQLite is active.
2. Click **Cargar datos demo**.
3. Confirm patient **Paciente Chrome** is selected.
4. Confirm food **Yogur griego Chrome · Demo PY** is selected.
5. Leave quantity at **150 g**.
6. Click **Crear y calcular plan**.
7. Confirm the result shows approximately:
   - 145.5 kcal
   - 13.5 g protein
   - 9.0 g carbohydrate
   - 6.0 g fat
8. Stop the app.
9. Run the same command again on port 8080.
10. Confirm the patient and food are still present.

## Out of scope for this first browser milestone

- Production USDA/FoodData Central browser catalog.
- Official catalog snapshot selection from the UI.
- Full weekly planner.
- Recipe editor.
- PDF generation.
- Food Swap.
- Mathematical optimization.
- Licensing/store integration.

Those are intentionally excluded so the first Chrome run isolates the core
platform, persistence and nutrition flow.
