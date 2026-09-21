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


# V0.3 — constructor semanal

La V0.3 convierte el laboratorio técnico en un flujo profesional de planificación.

## Alcance

- navegación Planificador / Biblioteca;
- selección de paciente;
- creación de semana nueva;
- 7 días;
- 5 comidas por día:
  - Desayuno
  - Media mañana
  - Almuerzo
  - Merienda
  - Cena
- múltiples alimentos por comida;
- recetas existentes reutilizables;
- alimentos propios o USDA;
- snapshot automático al usar USDA;
- eliminación de elementos;
- cálculo diario en tiempo real;
- resumen semanal visible por día;
- persistencia SQLite local.

## Prueba de aceptación

1. Abrir **Planificador**.
2. Seleccionar un paciente.
3. Pulsar **Nueva semana**.
4. Confirmar que aparecen Lunes a Domingo.
5. Elegir Lunes y Desayuno.
6. Buscar `leche` o cualquier alimento propio.
7. Elegir un resultado y agregar 150 g.
8. Agregar un segundo alimento a la misma comida.
9. Confirmar que ambos permanecen en Desayuno.
10. Confirmar que los totales del lunes se actualizan.
11. Cambiar a Martes.
12. Agregar otro alimento en Almuerzo.
13. Confirmar que el resumen semanal muestra valores distintos para Lunes y Martes.
14. Eliminar un elemento y confirmar recálculo.
15. Reiniciar Chrome en puerto 8080 y confirmar que la semana continúa guardada.

## Fuera de V0.3

- editor completo de recetas;
- drag & drop;
- copia rápida de día;
- plantillas;
- PDF;
- Food Swap;
- optimización matemática.

Estos módulos se agregan después de validar la ergonomía del constructor semanal.


# V0.4 — productividad del nutricionista

La V0.4 reduce pasos repetitivos dentro del planificador semanal.

## Incluye

- editar gramos de un alimento ya agregado;
- editar porciones de una receta;
- eliminar elementos;
- vaciar una comida completa;
- copiar una comida al mismo horario de otro día;
- copiar un día completo a otro día;
- duplicar una semana completa;
- seleccionar gramos o porciones domésticas cuando el alimento dispone de ellas;
- registrar medida casera y gramos de porción en alimentos propios o de marca.

## Conversión de porciones

Nutrikuaa conserva los cálculos internamente en gramos.

Ejemplo:

```text
Yogur
1 pote = 150 g

2 potes
↓
300 g internos
↓
cálculo nutricional
```

El texto de la medida puede utilizarse después para PDF y comunicación al
paciente.

## Prueba de aceptación V0.4

1. Abrir una semana existente.
2. En Lunes / Desayuno agregar un alimento con 150 g.
3. Pulsar editar y cambiar a 180 g.
4. Confirmar que los totales del lunes cambian inmediatamente.
5. Agregar un segundo alimento.
6. Usar **Copiar comida** y copiar Desayuno a Martes.
7. Confirmar que Martes recibe los mismos elementos.
8. Usar **Copiar día** de Lunes a Miércoles.
9. Confirmar que todas las comidas del lunes se reproducen en miércoles.
10. Vaciar una comida y confirmar recálculo.
11. Pulsar **Duplicar semana** y confirmar una nueva semana con los mismos
    alimentos.
12. En Biblioteca crear un alimento con:
    - medida casera: `1 pote`;
    - porción habitual: `150 g`.
13. Volver al Planificador, buscar ese alimento y elegir **Porción doméstica**.
14. Agregar 2 porciones y comprobar que Nutrikuaa calcula como 300 g.
15. Reiniciar Chrome en puerto 8080 y confirmar persistencia.

## Próximo hito después de V0.4

V0.5 será el editor profesional de recetas:

```text
Receta
  ↓
ingredientes
  ↓
cantidades
  ↓
rendimiento
  ↓
porciones
  ↓
nutrición automática
  ↓
reutilización en cualquier plan
```


# V0.5 — recetas profesionales

La V0.5 incorpora una biblioteca de recetas reutilizables y calculadas
automáticamente.

## Incluye

- sección propia **Recetas**;
- crear receta;
- nombre y descripción;
- preparación / indicaciones;
- número de porciones;
- rendimiento final opcional en gramos;
- búsqueda unificada de ingredientes:
  - alimentos propios;
  - marcas locales;
  - USDA Foundation Foods;
- snapshot automático cuando se utiliza un ingrediente USDA;
- varios ingredientes por receta;
- edición de gramos por ingrediente;
- eliminación de ingredientes;
- nutrición total de la receta;
- nutrición por porción;
- duplicar receta;
- editar receta mientras todavía no se utilizó en un plan;
- protección de recetas ya usadas en planes;
- reutilización directa desde el Planificador semanal.

## Regla de integridad

Una receta ya utilizada en un plan no se modifica ni se elimina directamente.

Para crear una variante:

```text
Receta usada
   ↓
Duplicar
   ↓
Editar copia
   ↓
Nueva versión profesional
```

Esto evita que un plan entregado a un paciente cambie retroactivamente.

## Prueba de aceptación V0.5

1. Abrir **Recetas**.
2. Crear `Omelette proteico`.
3. Definir, por ejemplo:
   - 2 porciones;
   - rendimiento 300 g.
4. Buscar y agregar al menos dos ingredientes.
5. Usar al menos un alimento USDA y uno de la biblioteca profesional.
6. Confirmar que aparecen los cálculos:
   - energía;
   - proteína;
   - carbohidratos;
   - grasas;
   - total;
   - por porción.
7. Editar los gramos de un ingrediente y verificar recálculo inmediato.
8. Guardar la receta.
9. Volver al **Planificador**.
10. Seleccionar **Recetas** en el agregador de comida.
11. Buscar `Omelette proteico`.
12. Agregar 1 porción.
13. Confirmar que los totales del día cambian con el valor de una porción.
14. Volver a **Recetas** e intentar modificar la receta utilizada.
15. Nutrikuaa debe impedir la edición para proteger el plan.
16. Pulsar **Duplicar**, modificar la copia y guardarla.
17. Reiniciar Chrome en puerto 8080 y confirmar persistencia.

## Próximo hito

V0.6 cerrará la ficha profesional del paciente y objetivos:

```text
Paciente
  ↓
datos básicos
  ↓
antropometría / notas
  ↓
objetivos nutricionales
  ↓
planes e historial
```


# V0.7.1 — branding profesional local

La V0.7.1 permite que cada profesional use su propio logo sin nube.

## Incluye

- selector local de archivos multiplataforma;
- formatos aceptados: PNG y JPG/JPEG;
- límite de 2 MB;
- validación básica de firma del archivo;
- vista previa del logo;
- almacenamiento local del logo dentro de SQLite;
- nombre original del archivo;
- uso automático del logo profesional en PDFs;
- fallback al logo Nutrikuaa;
- opción para volver al logo Nutrikuaa en cualquier momento;
- migración aditiva de base de datos v6 → v7.

## Prueba de aceptación V0.7.1

1. Abrir **Documentos**.
2. Confirmar que inicialmente aparece el logo Nutrikuaa o el logo ya guardado.
3. Pulsar **Cargar logo**.
4. Elegir un PNG o JPG menor de 2 MB.
5. Confirmar que la vista previa cambia.
6. Generar el PDF de un paciente.
7. Confirmar que el logo profesional aparece en la cabecera.
8. Cerrar la app y volver a ejecutar Chrome en puerto 8080.
9. Confirmar que el logo profesional sigue guardado.
10. Pulsar **Usar logo Nutrikuaa**.
11. Generar otro PDF y confirmar el fallback.

## Próximo hito

V0.8 cerrará la portabilidad y configuración del producto:

```text
Configuración
   ↓
idioma / región / unidades
   ↓
backup local
   ↓
restaurar backup
   ↓
datos portables
```


# V0.8.1 — interfaz internacional + backup cifrado

La V0.8.1 completa la presentación profesional en tres idiomas y añade
protección opcional para backups que contengan datos reales de pacientes.

## Interfaz

Idiomas disponibles: Español, English y Português.

El cambio de idioma actualiza navegación principal, Planificador, Pacientes,
Recetas, Documentos, Biblioteca, Configuración, mensajes principales, días,
comidas y el PDF profesional.

Los nombres canónicos internos de comidas no se migran ni se duplican. La
traducción se aplica en presentación para mantener compatibilidad con planes y
backups anteriores.

## Backup cifrado opcional

En Configuración → Backup y restauración se puede activar:

**Cifrar backup con contraseña**

Si está desactivado, se mantiene el backup portable V0.8.

Si está activado, Nutrikuaa solicita contraseña y confirmación, exige al menos
8 caracteres, deriva una clave con PBKDF2-HMAC-SHA256 y cifra el backup con
AES-256-GCM autenticado. El salt y el nonce son aleatorios y se almacenan en
el sobre cifrado. La contraseña no se guarda.

La restauración detecta automáticamente si un archivo .nutrikuaa está cifrado
y solicita la contraseña antes de poder inspeccionar o modificar datos locales.

## Prueba de aceptación V0.8.1

1. Abrir Configuración.
2. Cambiar idioma a English y guardar.
3. Recorrer Planner, Patients, Recipes, Documents, Library y Settings.
4. Confirmar que textos de interfaz, días y comidas aparecen en inglés.
5. Cambiar a Português y repetir una revisión rápida.
6. Volver al idioma deseado.
7. Activar Cifrar backup con contraseña.
8. Crear un backup con una contraseña de al menos 8 caracteres.
9. Confirmar que se descarga un archivo con sufijo _secure.nutrikuaa.
10. Intentar restaurarlo con contraseña incorrecta: no debe tocar los datos.
11. Restaurarlo con la contraseña correcta.
12. Confirmar pacientes, planes, recetas, logo y configuración.
13. Crear también un backup sin contraseña para comprobar compatibilidad V0.8.

## Seguridad

El cifrado protege el archivo exportado. No reemplaza las medidas de seguridad
del dispositivo donde se ejecuta Nutrikuaa. Las claves no se almacenan ni se
pueden recuperar desde la aplicación.
