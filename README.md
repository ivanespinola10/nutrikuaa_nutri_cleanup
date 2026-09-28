# Nutrikuaa Nutri

Aplicación local-first para nutricionistas independientes. Permite crear
pacientes, alimentos propios, recetas y planes semanales, calcular nutrientes y
exportar documentos. El catálogo USDA se empaqueta como archivo SQLite fijo;
no se consulta USDA durante el uso.

La aplicación activa vive en `lib/nutri/` y arranca desde `lib/main.dart`.
El legado industrial de Pro se retiró de la rama de limpieza; el historial de
Git lo conserva. Consulte `PRODUCT_SPEC.md` y `ARCHITECTURE.md` antes de
modificar el producto.

## Primer recorrido en Chrome

Consulte `docs/CHROME_MVP.md` para preparar el worker SQLite Web y ejecutar
`flutter run -d chrome --web-port 8080`. Use siempre el mismo origen y puerto
para conservar los datos locales de esa prueba.

## Comprobaciones

```text
python -m unittest discover -s tools/food_importer -p "test_*.py"
flutter analyze
flutter test
flutter build web
```

El catálogo oficial se genera fuera de la app con
`tools/food_importer/import_usda.py`; la versión incluida se registra en
`assets/data/food_db_manifest.json`. Una nueva versión se verifica por SHA-256
y estructura SQLite antes de activarse. La base profesional se almacena aparte
y nunca se reemplaza al actualizar el catálogo.

## Venta

El modelo propuesto es app web y compra única mediante Lemon Squeezy, sin
suscripción ni login permanente para el uso profesional. El diseño de checkout
y activación está en `docs/WEB_COMMERCE.md`. Aún no se aceptan pagos desde la
app; el flujo debe probarse en modo de prueba antes de ofrecer ventas.
