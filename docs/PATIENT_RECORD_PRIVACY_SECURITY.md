# Ficha de pacientes y privacidad — diseño para beta

Estado: ficha longitudinal en implementación y revisión técnica inicial; no constituye
validación clínica, prueba de penetración ni asesoría jurídica.

## Estado previo a la ficha longitudinal

- La ficha guarda nombre, apellido, nacimiento, sexo opcional, contacto,
  notas libres, estado activo y objetivos de energía/macronutrientes/fibra/sodio.
- Las mediciones longitudinales guardan fecha, peso, talla, cintura y nota; la
  ficha lista planes anteriores. Archivar un paciente sólo cambia is_active.
- Los registros de pacientes y planes están en SQLite local del navegador.
  No hay autenticación ni cifrado del almacenamiento activo. El backup se
  puede cifrar con contraseña, pero también se puede exportar sin cifrar.
- El repositorio no incluye Firebase Auth/Firestore ni Analytics en
  pubspec.yaml. No hay política de privacidad, condiciones de uso o aviso
  de almacenamiento publicados en la app. Falta verificar cookies y tráfico
  de la versión desplegada en un navegador.
- No existe borrado definitivo por paciente, borrado de toda la base local,
  autoservicio de licencia o cierre de cuenta. Hoy no existe cuenta Nutri.
- Las búsquedas de pacientes y los valores del catálogo SQL usan parámetros.
  La búsqueda de pacientes interpreta % y _ como comodines LIKE; conviene
  tratarlos literalmente. Esto no es evidencia de inyección SQL. No hay
  servidor SQL expuesto en el flujo actual.

## Ficha propuesta

Separar un resumen rápido de la evaluación inicial y de las consultas.
Mostrar secciones opcionales sólo cuando el profesional las necesite.

| Sección | Datos mínimos y uso |
| --- | --- |
| Identificación | Nombre, contacto, nacimiento opcional, identificador interno y persona de contacto sólo si procede. |
| Motivo y objetivos | Motivo de consulta, derivación, objetivo acordado, prioridad y fecha de revisión. |
| Alimentación y contexto | Patrón habitual, horarios, preferencias, restricciones, cultura, presupuesto, acceso y capacidad para cocinar. |
| Seguridad clínica | Alergias reportadas, reacción y fuente de confirmación, intolerancias diferenciadas, condiciones y medicación relevantes. No inferir diagnósticos. |
| Evaluación | Mediciones fechadas con unidad y método; analíticas sólo si son pertinentes, con fecha, unidad, rango y fuente. |
| Consulta | Fecha, profesional, hallazgos, intervención, objetivos, barreras, adherencia reportada y próxima revisión. |
| Resultados | Evolución de indicadores, versiones de planes entregados y PDF asociado. Conservar historial. |

Historia familiar, embarazo/lactancia, menores y otros datos muy sensibles
deben aparecer sólo cuando la práctica profesional lo justifique. No usar
escalas clínicas o diagnósticos automáticos sin validación y licencia.

## Modelo técnico incremental

La primera entrega añade campos de evaluación inicial opcionales a patients
y separación entre alergias e intolerancias reportadas. patient_encounters
incluye fecha, evaluación, problema nutricional redactado por
el profesional, intervención, seguimiento, próxima revisión, fuente y plan
opcional vinculado. Los registros existentes se conservan por migración
aditiva. Las observaciones antropométricas siguen en patient_measurements.
Los indicadores manuales fechados con valor, unidad, rango informado y
fuente se guardan en patient_observations, sin interpretación automática.
El historial de consultas e indicadores entra al backup versión 3; versiones 1 y 2 se
pueden restaurar sin consultas previas.

Siguientes ampliaciones propuestas, sujetas a prueba con profesionales:

1. patient_encounters: id, patient_id, date, reason, assessment,
   intervention, follow_up, plan_id opcional, created_at, updated_at.
   Cada visita es un registro separado.
2. patient_history_items: id, patient_id, category, label, description,
   status, source, recorded_at, reviewed_at. Categorías iniciales:
   preferencia, restricción, alergia reportada, condición o medicación
   relevante. No tratar la lista como diagnóstico validado.
3. patient_observations: id, patient_id, encounter_id opcional, type,
   value, unit, observed_at, source, method, notes. Permite medidas y
   analíticas fechadas con unidad y procedencia.
4. Migración SQLite aditiva; incluir tablas en backup y restauración; probar
   restauración desde una versión anterior. Consultas con patient_id
   parametrizado. El PDF sólo incluye lo que el profesional seleccione.

## Privacidad y seguridad antes de datos reales

| Prioridad | Condición verificable |
| --- | --- |
| Beta actual | Testers usan fichas ficticias. La URL de Hosting es pública aunque el repositorio sea privado. |
| P0 | Publicar un aviso claro de qué queda en el navegador, qué sale en PDF/backup y qué terceros reciben datos de compra o soporte. Revisar tráfico y cookies antes de afirmar que no hay rastreo. |
| P0 | Añadir exportación y borrado definitivo por paciente, con confirmación y alcance explícito sobre planes, mediciones y backups. El borrado local no elimina archivos ya exportados. |
| P0 | Proteger acceso en dispositivo compartido y definir cifrado del almacenamiento activo o un límite explícito de uso con datos reales. Probar pérdida del navegador y recuperación con backup cifrado. |
| P0 | Revisar consultas, dependencias, CSP/cabeceras compatibles con Flutter Web, contenido exportado y controles de despliegue. Una prueba de inyección aislada no equivale a auditoría completa. |
| P1 | Documentar responsables del tratamiento: Nutrikuaa para ventas/soporte y profesional para expedientes; bases jurídicas, finalidades, conservación, destinatarios, contacto y solicitudes. Validación jurídica por mercado. |
| P1 | Cuando exista compra/activación, separar baja o reembolso de licencia de borrado de expedientes. Recuperar acceso sin enviar datos de pacientes. |

No añadir un banner de consentimiento de cookies por rutina: primero
inventariar tecnologías y clasificar almacenamiento o seguimiento no
esencial por mercado. El aviso de almacenamiento local debe ser entendible.

## Criterios para implementar

- El profesional completa la ficha básica rápidamente y amplía la historia
  durante la consulta sin perder el contexto del plan.
- Cada observación y visita muestra fecha y fuente; validar fechas y unidades.
  Ausencia de dato no equivale a cero o a un diagnóstico.
- Archivar, eliminar y restaurar tienen significados distintos y se prueban
  con planes, mediciones, PDF y backups. La eliminación no promete borrar
  copias externas.
- En Chrome verificar con registros ficticios exportación, restauración,
  borrado, almacenamiento y tráfico de red. Antes de usar datos reales,
  revisar aviso y términos con asesoría jurídica.

Fuentes: Academy of Nutrition and Dietetics, Nutrition Care Process/Assessment
(eatrightpro.org); OWASP SQL Injection Prevention Cheat Sheet
(cheatsheetseries.owasp.org); Ley 7593/2025 de Paraguay (bacn.gov.py).
