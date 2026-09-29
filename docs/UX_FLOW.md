# Flujo profesional de Nutrikuaa Nutri

Revisión: 25 de septiembre de 2026. Producto: aplicación web local, pago único.

## Recorrido que se implementa

1. **Paciente y objetivos.** Crear la ficha en Pacientes, registrar objetivos y pasar al planificador desde el historial.
2. **Semana.** Crear o duplicar un plan. Los días sin alimentos se identifican como pendientes; los valores calculados se comparan con los objetivos definidos por el profesional.
3. **Componer.** Buscar alimentos oficiales o propios, usar recetas, ajustar cantidades y revisar el resumen por día. El catálogo conserva la fuente y las ediciones locales mantienen el historial de cálculos.
4. **Revisar y exportar.** Abrir Documentos con el mismo paciente y plan seleccionados. Antes de generar el PDF, avisar si hay días sin planificar o días cuya energía calculada difiere más de 15 % de la meta registrada. El profesional puede corregir el plan o continuar a la vista previa; la aplicación no decide pautas clínicas.
5. **Entrega.** El PDF agrupa cada día habitual en una tarjeta, enumera los días pendientes sin mostrarlos como 0 kcal y mantiene el título de preparaciones junto a la primera receta. El profesional comprueba el documento antes de compartirlo.

## Hallazgos de la prueba adjunta

El PDF de septiembre de 2026 dividía la tarjeta del miércoles entre dos páginas, imprimía sábado y domingo vacíos con 0 kcal y separaba el título «Preparaciones» de su receta. La energía de los días llenos era aproximadamente 1174 kcal frente a la meta registrada de 1800 kcal. Los nombres técnicos del catálogo oficial aparecían en inglés en un documento en español. Los ejemplos de recetas e identidad profesional eran de prueba.

El aviso de diferencia energética usa un umbral de revisión de interfaz del 15 %, sin interpretar necesidades nutricionales. Los nombres oficiales conservan su idioma y procedencia; para una entrega localizada el profesional puede crear una versión propia con nombre cercano al paciente y verificar sus nutrientes antes de usarla. La traducción automática de nombres de alimentos requiere un catálogo editorial verificado.

## Referencia competitiva y prioridad

| Producto | Flujo documentado por su fabricante | Decisión para Nutrikuaa |
| --- | --- | --- |
| [Nutrium](https://nutrium.com/professionals) | Planes personalizables, plantillas, recetas y seguimiento nutricional. | Reducir pasos entre paciente, semana, cálculo y entrega. |
| [That Clean Life](https://thatcleanlife.com/) | Planes, recetas y presentaciones para compartir con clientes. | Cuidar la lectura del PDF y el contexto práctico de la receta. |
| [NutriAdmin](https://nutriadmin.com/features/nutrition-analysis-software) | Clientes, planes, recetas y análisis nutricional en un mismo producto. | Guiar la revisión previa al documento sin añadir infraestructura continua. |

## Próximas iteraciones antes de venta

La beta privada, el guion de observación y los requisitos de alojamiento,
checkout y recuperación se detallan en [arquitectura de beta](PRIVATE_BETA_ARCHITECTURE.md)
y [protocolo de 15 minutos](TESTER_PROTOCOL.md). La lista de compras del
planificador ya agrega gramos de alimentos y recetas; las sustituciones y los
nombres regionales quedan sujetos a verificación profesional.

1. Probar con nutricionistas reales una tarea completa de 15 minutos: crear paciente y objetivos, componer tres días, corregir una cantidad y compartir el PDF. Registrar tiempo, errores y abandonos.
2. Incorporar nombres localizados verificados para los alimentos más usados en el mercado inicial y medidas domésticas regionales, conservando la fuente original.
3. Mejorar la composición de semanas largas: lista de compras y sustituciones manuales verificadas por el profesional; filtros por preferencias y restricciones sólo cuando sus datos sean confiables.
4. Completar el checkout de Lemon Squeezy, la activación y las condiciones explícitas de la licencia de compra única, con una recuperación de acceso viable y sin exponer datos de pacientes.

Esta mejora de interfaz no constituye una validación clínica ni una prueba de usabilidad con clientes reales.
# Biblioteca de alimentos (beta)

La sección **Pacientes** concentra el alta y los objetivos. **Planificador**
concentra la composición y el cálculo de planes. **Biblioteca** muestra el
catálogo oficial, la búsqueda y las fichas de alimentos propios; ya no crea
pacientes ni planes de prueba.

En **Nuevo alimento** se guardan energía y macronutrientes por 100 g, una
referencia obligatoria y, cuando existan datos confiables, fibra, azúcares,
micronutrientes, porción, medida casera y alérgenos declarados. Los campos
opcionales vacíos permanecen desconocidos. Una lista de alérgenos vacía no
significa que el alimento sea seguro para personas alérgicas. Los alimentos
oficiales conservan sus referencias y son de solo lectura.
