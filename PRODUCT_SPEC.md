# NutriKuaa Nutri — Product Specification

**Versión:** 0.2  
**Estado:** Definición inicial del producto

---

## 1. Propósito

NutriKuaa Nutri es una herramienta profesional para nutricionistas
independientes y pequeños consultorios.

Su objetivo principal es reducir el tiempo y trabajo repetitivo necesario
para crear, calcular, modificar, reutilizar y entregar planes nutricionales.

Está orientado a profesionales que actualmente utilizan combinaciones de
Excel, calculadoras, tablas de composición de alimentos, documentos y PDF
para realizar estas tareas.

---

## 2. Usuario principal

El usuario que compra y utiliza NutriKuaa Nutri es el nutricionista.

Usuarios objetivo iniciales:

- nutricionistas independientes;
- pequeños consultorios nutricionales;
- profesionales que atienden múltiples pacientes;
- profesionales que elaboran planes nutricionales manualmente;
- profesionales que reutilizan recetas y estructuras de planes.

NutriKuaa Nutri no pretende inicialmente ser un sistema hospitalario,
ERP médico ni plataforma administrativa de clínicas.

---

## 3. Problema principal

La elaboración de planes nutricionales requiere muchas tareas repetitivas:

1. Crear y organizar pacientes.
2. Definir objetivos nutricionales.
3. Buscar alimentos.
4. Consultar su composición nutricional.
5. Definir cantidades.
6. Realizar cálculos.
7. Crear recetas y preparaciones.
8. Distribuir alimentos y recetas entre comidas.
9. Comparar el resultado con los objetivos.
10. Modificar cantidades y volver a calcular.
11. Preparar un documento para entregar al paciente.
12. Reutilizar información en futuras consultas.

NutriKuaa Nutri debe reducir significativamente este trabajo manual.

---

## 4. Propuesta de valor

NutriKuaa Nutri permite al nutricionista crear planes nutricionales
utilizando bibliotecas reutilizables de pacientes, alimentos y recetas,
mientras la aplicación realiza automáticamente los cálculos nutricionales.

El profesional debe poder dedicar su tiempo a las decisiones nutricionales,
no a realizar cálculos y tareas repetitivas.

---

## 5. Principios del producto

### 5.1 Local-first

La información profesional debe almacenarse principalmente en el dispositivo
del usuario.

El funcionamiento principal no debe depender de una conexión permanente
a Internet.

### 5.2 Privacidad

Los datos del nutricionista, sus pacientes, recetas y planes pertenecen
al profesional.

No se almacenarán obligatoriamente en servicios cloud para utilizar
las funciones principales del producto.

### 5.3 Compra única

El modelo comercial inicial será de pago único.

Se evitarán funciones con costos variables permanentes que hagan
insostenible este modelo.

### 5.4 Sin IA generativa obligatoria

El producto base no dependerá de chats o modelos de IA que generen
costos por consulta.

### 5.5 Reutilización

Pacientes, alimentos, recetas y planes deben poder reutilizarse para
reducir trabajo repetitivo.

### 5.6 Bajo mantenimiento

El producto debe diseñarse pensando en una operación sostenible para
un equipo pequeño.

Se evitará complejidad técnica que no produzca valor claro para el usuario.

---

## 6. Biblioteca de pacientes

La biblioteca de pacientes será uno de los elementos centrales del producto.

Debe permitir:

- crear pacientes;
- editar pacientes;
- buscar pacientes;
- archivar pacientes;
- acceder a sus planes;
- consultar planes anteriores;
- duplicar planes;
- reutilizar planes como punto de partida.

Cada paciente podrá tener múltiples planes nutricionales.

La versión inicial no pretende implementar una historia clínica completa.

---

## 7. Biblioteca de alimentos

Debe existir una biblioteca de alimentos reutilizable y extensible.

Permitirá:

- buscar alimentos;
- consultar composición nutricional;
- utilizar bases oficiales de diferentes países y regiones;
- crear alimentos personalizados;
- registrar productos comerciales con nombre y marca;
- registrar porción declarada y medida doméstica;
- identificar la fuente de cada alimento;
- editar alimentos creados por el usuario;
- utilizar alimentos en recetas;
- utilizar alimentos directamente en planes.

### 7.1 Alimentos oficiales y personalizados

Los alimentos oficiales y los cargados por el profesional deben mantenerse
diferenciados.

Un alimento oficial conservará su fuente y no será editable directamente.

Un alimento personalizado podrá provenir de:

- una etiqueta nutricional de una marca;
- una preparación o alimento habitual del profesional;
- una importación realizada por el usuario.

Ejemplo:

```text
Yogur griego
Marca: Lactolanda
Porción: 150 g
País: PY
Fuente: Etiqueta cargada por el profesional
```

Una vez creado, el alimento queda disponible en la biblioteca profesional y
puede agregarse inmediatamente al plan actual, reutilizarse en otros
pacientes y aparecer con su marca en el documento entregado.

El objetivo es permitir planes más familiares y accionables para el paciente
sin perder trazabilidad nutricional.

### 7.2 Estructura mundial

La composición nutricional debe admitir un número extensible de nutrientes en
lugar de depender de un conjunto fijo de columnas.

La base oficial distribuida con el producto será un archivo local cerrado y
versionado. No dependerá de scraping ni de descargas desde servicios externos
para que el usuario pueda instalar o utilizar NutriKuaa.

Las nuevas versiones de bases oficiales serán preparadas y validadas por
NutriKuaa antes de incorporarse a una actualización de la aplicación.

Los alimentos, marcas y recetas creados por el profesional se almacenarán
separadamente y nunca serán reemplazados por una actualización del catálogo.

Cada alimento podrá conservar:

- país o región;
- base de origen;
- identificador en la fuente;
- versión futura del dataset;
- marca, cuando corresponda;
- valores por 100 g;
- porción y medida doméstica.

Esto permitirá incorporar progresivamente bases alimentarias regionales sin
rediseñar el núcleo del producto.

---

## 8. Biblioteca de recetas

Las recetas pertenecen a la biblioteca profesional del nutricionista
y no a un paciente específico.

Esto permite crear una receta una sola vez y reutilizarla en diferentes
pacientes y planes.

Debe permitir:

- crear recetas;
- agregar alimentos;
- definir cantidades;
- editar recetas;
- duplicar recetas;
- definir porciones;
- calcular composición nutricional;
- guardar recetas;
- reutilizarlas en diferentes planes.

---

## 9. Constructor de planes

El constructor de planes será el núcleo operativo de NutriKuaa Nutri.

Flujo básico:

Paciente
→ objetivos
→ nuevo plan
→ comidas
→ alimentos y recetas
→ cantidades
→ cálculo automático
→ comparación con objetivos
→ ajustes
→ guardar
→ generar documento

El usuario deberá poder modificar cantidades y observar inmediatamente
el impacto nutricional sobre el plan.

---

## 10. Cálculos

Como mínimo, la versión 1.0 deberá contemplar:

- energía;
- proteínas;
- carbohidratos;
- grasas;
- fibra;
- sodio;

y otros nutrientes cuando la base de alimentos disponga de ellos.

Los cálculos deben poder realizarse para:

- alimentos;
- recetas completas;
- porciones;
- comidas;
- plan diario.

---

## 11. Objetivos nutricionales

El profesional podrá definir objetivos para cada paciente.

El plan deberá poder comparar los valores calculados con los objetivos
establecidos.

Ejemplo:

| Nutriente | Objetivo | Plan | Diferencia |
|---|---:|---:|---:|
| Energía | 2000 kcal | 1950 kcal | -50 |
| Proteínas | 120 g | 118 g | -2 |
| Carbohidratos | 220 g | 225 g | +5 |
| Grasas | 65 g | 63 g | -2 |

---

## 12. PDF y entrega

El nutricionista podrá generar un documento profesional para entregar
al paciente.

Podrá incluir:

- profesional;
- paciente;
- fecha;
- comidas;
- alimentos;
- cantidades;
- recetas;
- indicaciones.

---

## 13. Seguimiento del paciente

La arquitectura deberá permitir en el futuro que un paciente pueda
registrar progreso desde su teléfono.

Ejemplos:

- peso;
- adherencia;
- cumplimiento del plan;
- observaciones;
- check-in periódico.

Esta información podrá posteriormente ser consultada por el nutricionista.

### Importante

El portal o aplicación del paciente NO forma parte del MVP 1.0.

Debe considerarse en la arquitectura para evitar bloquear su incorporación
futura.

El núcleo profesional continuará siendo local-first.

---

## 14. Fuera del MVP 1.0

No se desarrollarán inicialmente:

- agenda;
- reservas;
- facturación;
- cobros de consultas;
- videollamadas;
- WhatsApp integrado;
- chat de IA;
- generación de planes mediante IA;
- historia clínica completa;
- portal del paciente;
- sincronización cloud completa;
- marketplace;
- funciones sociales.

---

## 15. Modelo comercial

Modelo inicial:

Compra única
→ Lemon Squeezy
→ licencia
→ activación
→ uso local.

El software principal debe evitar costos variables elevados posteriores
a la venta.

Los servicios cloud opcionales futuros podrán tener un modelo comercial
independiente si generan costos recurrentes.

---

## 16. Criterio de éxito del MVP 1.0

Un nutricionista debe poder:

1. Crear un paciente.
2. Definir objetivos nutricionales.
3. Buscar y crear alimentos.
4. Crear recetas independientes.
5. Reutilizar recetas.
6. Crear un plan para un paciente.
7. Combinar alimentos y recetas.
8. Obtener cálculos automáticos.
9. Compararlos con los objetivos.
10. Modificar rápidamente el plan.
11. Guardarlo.
12. Reutilizarlo.
13. Generar un PDF profesional.

Todo ello sin depender permanentemente de Internet.