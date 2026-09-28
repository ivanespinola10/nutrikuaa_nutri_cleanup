# NutriKuaa Nutri — Agent Instructions

## 1. Project purpose

NutriKuaa Nutri is a professional nutrition planning application for
independent nutritionists and small nutrition practices.

Its primary goal is to reduce repetitive work involved in:

- managing patients;
- creating nutrition plans;
- calculating nutritional composition;
- reusing recipes and foods;
- comparing plans with nutritional targets;
- generating professional documents.

Before making changes, read:

1. PRODUCT_SPEC.md
2. ARCHITECTURE.md

These files define the product and architectural direction.

---

## 2. Product principles

The project must remain:

- local-first;
- simple to maintain;
- modular;
- suitable for a small development team;
- usable without permanent internet access;
- compatible with a one-time purchase business model.

Do not introduce recurring infrastructure costs unless explicitly requested.

---

## 3. Forbidden assumptions

Do not assume NutriKuaa Nutri needs:

- generative AI;
- chatbots;
- Firebase;
- cloud-first architecture;
- subscriptions;
- RevenueCat;
- mandatory login;
- patient portal;
- hospital workflows;
- appointment scheduling;
- billing;
- WhatsApp integration.

These features are outside the MVP unless explicitly requested.

---

## 4. Architecture rules

Follow the architecture described in ARCHITECTURE.md.

Conceptual layers:

```text
Presentation
    ↓
Application
    ↓
Domain
    ↓
Data
```

---

## 5. Nutri source boundary

The active application entry point is `lib/main.dart`. Product code belongs in
`lib/nutri/` (application, data, domain, localization and ui). Do not reintroduce
industrial Pro models, screens, costing or yield calculations. Keep Nutri
nutrition calculations in `lib/nutri/application/nutrition_calculator.dart`
and `plan_nutrition_service.dart`; daily totals use per-100-g nutrient values
and the saved meal day index.

The Nutri database is `nutrikuaa_nutri.db`; migrations must preserve user
data. Do not use destructive drop-and-recreate upgrades for professional
records. Historical plans must keep food composition snapshots.

---

## 6. Food catalog runtime rule

Official food databases must be generated offline by maintainers and bundled
as versioned release assets.

Do not add runtime web scraping, USDA/FoodData Central download dependencies,
or mandatory food APIs to the application.

`nutrikuaa_foods.db` is replaceable read-only reference data.
`nutrikuaa_nutri.db` contains professional/user data and must never be
overwritten by a food catalog update.

Existing plans must not silently change nutritional values when the official
catalog is upgraded; use stable references or snapshots/materialization.
