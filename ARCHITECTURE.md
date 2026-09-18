# NutriKuaa Nutri — Architecture

**Versión:** 0.2  
**Estado:** Backend local-first en construcción

---

## 1. Objetivo arquitectónico

NutriKuaa Nutri debe ser una aplicación:

- local-first;
- modular;
- fácil de mantener;
- apta para desarrollo asistido por agentes de IA;
- con lógica de negocio separada de la interfaz;
- con cálculos nutricionales testeables;
- preparada para incorporar sincronización opcional en el futuro.

La arquitectura debe priorizar claridad y bajo mantenimiento sobre complejidad innecesaria.

---

## 2. Principio principal

La interfaz de usuario no debe contener directamente:

- consultas SQL;
- cálculos nutricionales complejos;
- reglas de negocio;
- lógica de licencia;
- generación de PDF;
- sincronización futura.

Cada responsabilidad debe estar separada.

---

## 3. Capas

La aplicación se organizará conceptualmente en las siguientes capas:

```text
Presentation
     ↓
Application
     ↓
Domain
     ↓
Data
```

### Presentation

Pantallas, widgets y navegación. Solo presenta información y captura acciones.

### Application

Casos de uso y servicios que coordinan el dominio: cálculo, biblioteca de
alimentos, creación de planes, duplicación y exportación.

### Domain

Modelos y reglas independientes de Flutter y SQLite.

### Data

Persistencia SQLite, importadores de bases alimentarias y futuros adaptadores
opcionales de sincronización.

---

## 4. Separación del legado industrial

El código heredado de NutriKuaa Pro permanece temporalmente en las carpetas
existentes (`lib/core`, `lib/data`, `lib/models`, `lib/logic`,
`lib/services`, `lib/ui`).

El nuevo producto Nutri se desarrolla bajo:

```text
lib/nutri/
├── application/
├── data/
└── domain/
```

No se debe convertir `ProyectoModel` en paciente ni reutilizar
`proyecto_items` para comidas. Los conceptos industriales y clínicos son
dominios distintos.

La migración de la interfaz ocurrirá de forma incremental cuando el backend
Nutri esté estable.

---

## 5. Persistencia

NutriKuaa Nutri utiliza una base SQLite propia:

```text
nutrikuaa_nutri.db
```

La base industrial `nutrikuaa_industrial.db` no se modifica durante esta
etapa.

Las migraciones futuras deben preservar datos profesionales. No se permiten
migraciones destructivas que eliminen pacientes, recetas, planes o alimentos
personalizados.

---

## 6. Modelo de alimentos mundial

Los alimentos no se modelan con un conjunto rígido de columnas nutricionales.

```text
foods
  ↓
food_nutrients
```

Cada alimento puede tener cualquier cantidad de nutrientes identificados por
un código estable.

Esto permite incorporar diferentes bases oficiales nacionales o
internacionales sin rediseñar la base de datos.

Cada alimento registra su procedencia:

- base oficial;
- etiqueta de marca cargada por el profesional;
- alimento personalizado;
- importación externa.

Los alimentos oficiales son de solo lectura. Los alimentos creados por el
profesional son editables y forman parte de su biblioteca local.

---

## 7. Dominio clínico inicial

Entidades principales:

```text
Patient
NutritionTarget

Food
NutrientValue

Recipe
RecipeItem

MealPlan
Meal
MealItem
```

Un `MealItem` referencia exactamente un alimento o una receta.

Los planes soportan varios días mediante `dayIndex`, permitiendo implementar
planes semanales sin cambiar el esquema.

---

## 8. Local-first

Deben funcionar sin Internet:

- pacientes;
- alimentos y productos de marca;
- recetas;
- planes;
- cálculos;
- búsqueda;
- PDF;
- backup e importación/exportación cuando se implementen.

La conexión a Internet no debe ser requisito para abrir ni utilizar el núcleo
profesional.

---

## 9. Evolución futura

La arquitectura debe permitir, sin obligar al MVP a implementarlo:

- bases alimentarias descargables por país;
- sincronización opcional;
- portal del paciente;
- Smart Food Swap;
- optimización matemática de cantidades;
- importación de etiquetas;
- backup cifrado opcional.

Estas funciones deben añadirse alrededor del núcleo local, no reemplazarlo.
