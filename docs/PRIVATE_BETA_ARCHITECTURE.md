# Nutrikuaa Nutri: beta privada y arquitectura de venta web

**Estado (26-09-2026):** plan de ejecución; no hay despliegue protegido de la
app Flutter ni checkout Nutri conectado. La URL del prototipo anterior pertenece
a otro proyecto y no es una entrega de la app del repositorio.

## Arquitectura elegida

```text
Página comercial (al aprobarla) → Lemon Squeezy (producto Nutri separado)
                                        ↓ orden / clave / reembolso
                                  API mínima de licencia
                                        ↓ permiso firmado
Chrome → origen HTTPS Nutri → Flutter Web + catálogo SQLite versionado
                              ↓ SQLite local (pacientes y planes)
                              ↓ PDF / backup cifrado descargables
```

- **Código y publicación:** repositorio GitHub privado; CI ejecuta análisis,
  tests, preparación de SQLite Web y build. El artefacto Flutter Web se sube a
  alojamiento estático con HTTPS y URL estable. No se usa el prototipo de Sites
  como sustituto de este build. En beta, usar Cloudflare Pages con Access, y
  exigir autenticación sobre *todos* los nombres accesibles: URL de preview,
  `*.pages.dev` principal y dominio propio. No configurar un dominio alternativo
  abierto. La política permite únicamente correos de testers designados con
  código de un solo uso. La beta permanece bloqueada incluso si alguien conoce
  la URL. El dueño administra invitaciones y puede revocarlas.
- **Datos:** `nutrikuaa_foods.db` es asset oficial de solo lectura, construido
  offline con manifiesto, versión y hash. `nutrikuaa_nutri.db` reside en el
  almacenamiento de este origen y perfil de Chrome; contiene pacientes, planes,
  recetas, alimentos propios y snapshots usados. No hay API para subir fichas de
  pacientes ni analítica que las capture. El PDF se genera en el navegador; el
  usuario elige dónde guardarlo o a quién enviarlo. El backup cifrado se guarda
  por descarga, con contraseña distinta de la clave comercial. Borrar datos del
  sitio, cambiar perfil, origen o dispositivo requiere restaurar ese backup.
- **Localización:** primero es-PY; vocabulario `es-PY` y medidas domésticas sólo
  tras revisión editorial sobre el alimento, release y gramaje específicos. El
  nombre USDA y su procedencia se conservan. `review_localizations.py` comprueba
  el CSV y genera una propuesta JSON; su salida no modifica automáticamente el
  catálogo ni la app. Un mantenedor revisa la evidencia y empaqueta un nuevo
  catálogo versionado. Una medida sin gramaje comprobado queda sólo como texto
  libre del profesional, no como conversión automática. La interfaz no presenta
  traducciones todavía porque no existe un conjunto de revisiones aprobado.
- **Funciones locales:** objetivos indicados por el profesional, semana,
  cálculos, recetas, comparación, PDF y lista de compras por gramos. Las
  sustituciones se realizan editando manualmente el plan y comprobando los
  nutrientes; preferencias y restricciones clínicas no activan filtros hasta
  que sus taxonomías y cobertura por alimento estén verificadas. Nada de
  inferir alergias a partir del nombre del alimento.
- **Licencia comercial:** la cuenta de Lemon Squeezy ya usada para Nutrikuaa
  Pro puede alojar otro producto Nutri, con variante de pago único y claves
  separadas. La web no incluirá el secreto de firma ni la clave API de Lemon.
  Una API de licencias sin datos clínicos verificará el pago/estado y emitirá un
  permiso firmado verificable localmente; almacenará sólo referencias de pedido,
  licencia y dispositivos, jamás identificadores/nombres de pacientes. La
  activación inicial requiere red; el núcleo local funciona luego sin consultas
  por pantalla. Una revocación por reembolso no puede propagarse durante una
  desconexión: explicitarlo en la política y revalidar cuando vuelva la red.
  No prometemos protección inviolable de código cliente ni revocación instantánea
  sin conexión.

## Puesta a disposición de testers

1. Alinear PRs encadenadas con la rama principal y obtener CI verde; construir
   exactamente el commit aprobado, registrar SHA del build y hash del catálogo.
2. Preparar el alojamiento privado y Access **antes** de copiar artefactos;
   restringir tanto previews como dominio principal y `pages.dev`. Abrir cada
   origen conocido en una ventana anónima sin sesión: debe exigir acceso. Abrir
   con un correo no permitido: acceso denegado. Probar con correo permitido y
   código recibido: llega a la app. Si alguna ruta sirve el build libremente,
   retirar el artefacto y cerrar esa ruta antes de invitar a nadie.
3. Probar Chrome de escritorio con perfil limpio: catálogo y fuente visibles,
   ficha ficticia y objetivos, tres días, corrección, revisión, PDF, backup
   cifrado; cerrar y reabrir, repetir sin red tras cargar recursos; restaurar
   backup en un perfil vacío de ese mismo origen. Comprobar que no hay solicitud
   con pacientes en la pestaña Network. No usar pacientes reales en la beta.
4. Enviar por canal acordado URL protegida, invitación individual y ficha de
   tarea a 5–8 nutricionistas del mercado inicial. El correo del tester es
   identificador de acceso, no dato de paciente. Revocar al finalizar; no
   reutilizar una lista de acceso amplia. El facilitador observa con permiso,
   registra acciones sin grabar fichas y recoge el PDF ficticio sólo si el
   tester consiente compartirlo.
5. Priorizar fallos repetidos y volver a probar. Abrir pagos reales sólo tras
   acordar términos, soporte, precio e impuestos y validar checkout/activación
   de Nutri en modo prueba.

No hay URL de esta beta hasta completar alojamiento, política y prueba desde
Chrome sin sesión. Una URL de Pages o Firebase por sí sola no equivale a
privacidad; tampoco basta que el repositorio sea privado.

## Sesión observada de 15 minutos

Usar `docs/TESTER_PROTOCOL.md` y el CSV de resultados. Cada participante
trabaja con un paciente ficticio. El facilitador da la tarea completa, no
indica dónde hacer clic; sólo anota intervenciones. El tiempo se cuenta desde
que el tester recibe la tarea hasta que guarda el PDF y explica cómo lo
compartiría. Si excede 15 minutos, registrar etapa, duración y motivo sin
marcar la tarea como terminada. No atribuir a la interfaz validez clínica.

## Checkout y recuperación antes de vender

1. Crear producto Nutri separado en la misma cuenta Lemon y configurar una
   variante de pago único, límite de dos activaciones y clave por orden;
   documentar ID de tienda, producto y variante sólo como configuración. No
   suponer que la clave de Nutrikuaa Pro concede acceso a Nutri.
2. API mínima recibe webhook firmado, verifica firma sobre cuerpo original,
   producto/variante, idempotencia por ID de evento y estados pagado/reembolso;
   nunca confía en redirecciones del navegador como prueba de compra. El cliente
   envía clave para activación; el servidor usa el License API, limita
   dispositivos, devuelve permiso firmado con producto, versión, licencia y
   dispositivo. Guardar sólo metadatos indispensables, secretos fuera del repo.
3. Tras compra, mostrar recibo y pasos para guardar la clave; activación en la
   app web desde dispositivo autorizado. En reinstalación, clave+orden/correo
   de compra verifican titularidad mediante Lemon; desactivar dispositivo viejo
   con `instance_id` y activar nuevo. Si perdió la clave, enlace de pedido de
   Lemon o soporte con comprobante, sin solicitar archivos de pacientes.
4. Ensayar con Test Mode: compra, doble evento, clave inválida, dos activaciones,
   tercer dispositivo, baja, reembolso, dispositivo perdido, red caída y
   restauración de backup. Luego configurar dominio estable y política pública
   de privacidad, soporte, términos e impuestos. La aprobación del dueño es
   necesaria antes de página comercial o cobros públicos.

### Condiciones propuestas para revisión comercial y jurídica

Pago único por profesional para uso permanente de la **versión mayor comprada**
de Nutrikuaa Nutri en hasta dos dispositivos activos, sin límite artificial de
pacientes; versiones menores y correcciones incluidas durante [plazo de soporte
por definir]. Una nueva versión mayor puede venderse por separado. Licencia
personal del profesional, no transferible sin trámite de soporte; no incluye
sincronización, almacenamiento clínico ni servicios futuros de coste variable.
El usuario conserva y respalda sus datos; pérdidas del almacenamiento local se
recuperan sólo de su propio backup. Definir por escrito reembolso, impuestos,
soporte, cambio de dispositivo, cierre del servicio de activación y continuidad
de uso offline antes de cobrar. Precio fundador 99 USD y estándar 149 USD son
hipótesis, no ofertas vigentes ni precios configurados.

## Grietas de la arquitectura actual

| Área | Ya existe en la rama de Nutri | Falta para vender |
| --- | --- | --- |
| Núcleo Chrome | UI Flutter, pacientes, metas, semanas, PDF, catálogo fijo y backup | QA observado en Chrome y despliegue bajo Access |
| Catálogo | USDA 2026-04 y alimentos profesionales separados | Nombres/medidas regionales con evidencia y release aprobado |
| Semana larga | Copiar días/comidas, resumen y lista de compras por gramos | Sustituciones guiadas y medición de tiempo real |
| Licencia | Decisión comercial documentada | Producto Lemon, backend firmado, recuperación, términos |
| Seguridad | Datos locales y backup cifrado disponible | Auditoría de hosting, actualización de assets y comportamiento sin red |
