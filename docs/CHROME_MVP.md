# NutriKuaa Nutri — Chrome MVP

## V0.1 — aprobado

La primera prueba confirmó:

- SQLite Web operativo;
- persistencia entre reinicios en localhost:8080;
- pacientes;
- alimentos personalizados;
- objetivos nutricionales;
- creación de plan;
- lectura desde SQLite;
- cálculo de energía y macronutrientes.

## V0.2 — catálogo oficial + biblioteca profesional

Esta etapa añade una segunda base local:

```text
nutrikuaa_nutri.db
  pacientes
  objetivos
  alimentos/marcas del profesional
  snapshots usados en planes
  recetas y planes

nutrikuaa_foods.db
  USDA FoodData Central Foundation Foods
  release 2026-04
  solo referencia
```

El catálogo USDA se distribuye dentro de la aplicación. Chrome lo instala en
IndexedDB desde el asset local; la app no consulta ni descarga USDA durante el
uso.

### Catálogo incluido

La compilación actual contiene:

- 469 Foundation Foods;
- 3.841 valores nutricionales normalizados;
- 187 porciones/medidas disponibles;
- fuente: USDA FoodData Central Foundation Foods 2026-04.

## Preparar y ejecutar

```powershell
git pull origin feature/nutri-backend-foundation
flutter clean
.\scripts\prepare_chrome.ps1
flutter run -d chrome --web-port 8080
```

## Prueba de aceptación V0.2

1. Confirmar que se muestran dos estados activos:
   - Base profesional activa.
   - USDA activo.
2. En **Buscar alimento**, escribir `milk`.
3. Confirmar que los alimentos propios aparecen en **Mi biblioteca** cuando
   coinciden con la búsqueda.
4. Confirmar resultados en **USDA Foundation Foods**.
5. Elegir un alimento USDA con **Usar**.
6. Elegir un paciente.
7. Dejar una cantidad, por ejemplo 150 g.
8. Pulsar **Guardar y calcular plan**.
9. Confirmar que aparecen los totales nutricionales.
10. Volver a buscar el mismo alimento.
11. El registro utilizado ya debe aparecer desde la biblioteca profesional
    como snapshot y no duplicarse como resultado oficial equivalente.

El snapshot conserva:

- fuente;
- FDC ID;
- release;
- composición nutricional usada;
- porciones disponibles.

Una actualización futura del catálogo oficial no modifica ese plan histórico.

## Nota de idioma

Foundation Foods utiliza descripciones oficiales en inglés. En esta etapa
buscar `milk`, `rice`, `chicken`, `egg`, etc.

La capa multilingüe de nombres/sinónimos se implementará más adelante sin
modificar los valores oficiales ni perder trazabilidad.

## Después de V0.2

Con catálogo + snapshots aprobados, el siguiente hito es sustituir el
laboratorio por el constructor semanal real:

```text
Paciente
  ↓
Plan
  ↓
Lun Mar Mié Jue Vie Sáb Dom
  ↓
Desayuno / Media mañana / Almuerzo / Merienda / Cena
  ↓
alimentos + recetas
  ↓
totales en tiempo real
```
