# Nutrikuaa Nutri — Beta de preventa

Esta beta agrega un flujo demostrable y funcional sin romper el principio local-first.

## Incluido ahora

- Biblioteca organizada en **Alimentos** y **Recetas**.
- Selector de fuente en alimentos: **Todas**, **Mi biblioteca** o **USDA**.
- **Nutri IA · Beta offline** dentro del Planificador.
- Entrada en lenguaje natural para prearmar el día seleccionado.
- Detección básica de preferencias: alto en proteína, económico, vegetariano/vegano, sin lactosa, sin gluten, sin huevo y sin frutos secos/maní.
- Selección de alimentos únicamente desde bases locales activas.
- Cálculo de energía y macronutrientes con el motor nutricional existente de Nutrikuaa.
- Aplicación del borrador al día seleccionado, dejando todos los alimentos y cantidades editables.
- Materialización de alimentos oficiales mediante el flujo existente, preservando la estabilidad de planes históricos.

## Qué NO se afirma en preventa

La primera beta no incorpora todavía un LLM generativo descargable. El flujo usa un motor local determinístico de reglas + búsqueda + cálculo nutricional. Esto permite validar la experiencia con nutricionistas reales sin aumentar el tamaño de la app ni crear costos de API.

La interfaz y el contrato del servicio están separados del motor, de modo que una segunda etapa puede sustituir la interpretación de reglas por un modelo local cuantizado sin cambiar el constructor de planes ni el almacenamiento.

## Mensaje comercial sugerido

> Nutrikuaa Nutri acelera la creación de planes con un asistente privado y local. El profesional describe el tipo de plan, Nutrikuaa prepara un borrador usando sus bases alimentarias y realiza los cálculos automáticamente. El nutricionista conserva el control final y puede editar cada alimento y cantidad antes de entregar el plan.

## Criterio de validación de preventa

La beta cumple su objetivo si un nutricionista puede crear o seleccionar un paciente, abrir una semana, describir un día alimentario, generar un borrador offline, revisarlo, aplicarlo y continuar editando el plan sin salir del Planificador.

## Validador independiente del borrador

Nutri IA genera el borrador y una segunda capa local independiente vuelve a revisar:
- energía y macronutrientes contra las metas disponibles;
- restricciones expresadas en el pedido;
- alergias e intolerancias registradas en la ficha del paciente;
- cantidades inválidas o extremas;
- disponibilidad mínima de composición nutricional.

Una incompatibilidad dura bloquea la acción "Aplicar borrador". Las advertencias no equivalen a aprobación clínica y siempre requieren revisión profesional.