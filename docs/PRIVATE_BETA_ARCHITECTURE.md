# Nutrikuaa Nutri: beta privada y arquitectura de venta web

**Estado (26-09-2026):** plan de ejecución; no hay despliegue protegido de la
app Flutter ni checkout Nutri conectado. La URL del prototipo anterior pertenece
a otro proyecto y no es una entrega de la app del repositorio. Se prioriza
reutilizar el proyecto Firebase `nutrikuaa` y reducir los gastos recurrentes.

## Arquitectura elegida

```text
Página comercial (al aprobarla) → Lemon Squeezy (producto Nutri separado)
                                        ↓ orden / clave / reembolso
                                  API mínima de licencia
                                        ↓ permiso firmado
Chrome → Cloud Run con IAP (beta) / Firebase Hosting (venta aprobada)
                             → Flutter Web + catálogo SQLite versionado
                              ↓ SQLite local (pacientes y planes)
                              ↓ PDF / backup cifrado descargables
```

- **Código y publicación:** repositorio GitHub privado; CI ejecuta análisis,
  tests, preparación de SQLite Web y build. El artefacto Flutter Web se empaqueta
  con `deploy/beta/Dockerfile` y se sirve por Cloud Run con Identity-Aware Proxy
  (IAP) y `--no-allow-unauthenticated`. IAP se activa antes de entregar el
  build y controla también la URL `run.app`. El dueño autoriza sólo correos de
  testers concretos; los externos requieren audiencia OAuth externa y política
  IAP adecuada. No conectar el dominio de beta a un Firebase Hosting ni crear
  preview channels para este build: sus enlaces son públicamente accesibles.
  Tras autorización de lanzamiento comercial, `firebase.json` prepara *el mismo*
  Flutter Web para un sitio secundario de Firebase Hosting dentro del proyecto
  `nutrikuaa`. El `target` obligatorio `nutri` evita que esta configuración
  despliegue sobre el sitio predeterminado de Nutrikuaa Pro; hay que crear el
  sitio, asignarle el target y ejecutar **sólo** `hosting:nutri` con
  `--project nutrikuaa`. El repositorio hereda identificadores Flutter del
  proyecto Pro: revisar reglas, secretos, IAM y endpoints compartidos antes
  de conectar cualquier recurso. Los datos profesionales permanecen locales.
  No se usa el prototipo de Sites como sustituto de este build.
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
- **Licencia comercial:** crear Nutri como producto y claves distintos en la
  cuenta Lemon Squeezy ya usada por Pro. Auditar el código y los permisos de la
  función comercial de Pro antes de extenderla; si admite el nuevo producto,
  compartir su despliegue y ruta, aislando las licencias por producto/variante.
  Sólo añadir una función mínima si la existente no permite ese aislamiento.
  No abrir Firestore ni Auth por defecto: evaluar persistencia comercial mínima
  después de probar webhooks duplicados, reembolsos y recuperación con Lemon.
  Mantener secretos de webhook/API/firma fuera del cliente y del repositorio.
  La app no envía pacientes ni recetas al backend. La primera activación requiere
  red; el núcleo local continúa sin llamadas por pantalla. La revocación por
  reembolso se aplicará al reconectar según términos expresos, nunca de modo
  instantáneo estando desconectado. No prometer protección inviolable del
  código cliente.

## Costos y aislamiento

- **Beta de corta duración:** Cloud Run en el proyecto `nutrikuaa`, región de
  bajo costo `us-central1`, facturación por petición, cero instancias mínimas,
  IAP directo sobre `run.app` y sin balanceador ni dominio nuevo. Registrar uso
  de Cloud Run, transferencia, build y almacenamiento de imágenes; borrar el
  servicio y las imágenes al concluir la prueba. La cuota gratuita puede cubrir
  un piloto pequeño, pero no garantiza factura cero. IAP y una compilación
  pesada pueden aumentar latencia percibida en Paraguay; medirla aparte de las
  tareas de usabilidad.
- **Web comercial:** sitio secundario estático `nutrikuaa-nutri.web.app` si
  está disponible, dentro de `nutrikuaa`; CDN, almacenamiento y sus cuotas se
  comparten con Pro. Mantener el bundle pequeño y limitar releases antiguos.
  No habilitar Firebase App Hosting, base de pacientes, sincronización cloud,
  funciones permanentes para cálculos ni dominio de pago sólo para lanzar V1.
- **Control:** consultar uso actual de Pro antes del piloto y vigilar cuota
  conjunta. Configurar alertas de presupuesto; son avisos, no topes de gasto.
  Para un aislamiento estricto de facturación o IAM se puede migrar Nutri a un
  proyecto propio más adelante sin cambiar la estrategia local de datos.

### Preparación del sitio comercial, sin publicar aún

```sh
firebase hosting:sites:create nutrikuaa-nutri --project nutrikuaa
firebase target:apply hosting nutri nutrikuaa-nutri --project nutrikuaa
firebase deploy --only hosting:nutri --project nutrikuaa
```

El ID del sitio es global: reemplazar `nutrikuaa-nutri` si ya existe; mantener
`target` como `nutri`. El último comando sólo procede tras autorizar la salida
pública, revisar el origen del bundle y comprobar el checkout. No ejecutar
`firebase deploy --only hosting` sin el target explícito: afecta todos los
sitios configurados. Firebase Hosting y sus canales preview sirven archivos
públicamente; no son un control de acceso para los testers privados.

## Puesta a disposición de testers

1. Alinear PRs encadenadas con la rama principal y obtener CI verde; tomar el
   artefacto `nutrikuaa-nutri-web-<commit>` del CI de ese commit (retención siete
   días) y registrar SHA del build y hash del catálogo. Ese archivo privado de
   Actions aún no es un sitio accesible a los testers.
2. Crear el servicio Cloud Run de beta en `nutrikuaa` sin invocaciones anónimas, activar IAP y
   configurar su OAuth para testers externos. Verificar la política de acceso
   con una página inocua **antes** de subir la app. Probar URL `run.app` y todo
   dominio adjunto en ventana anónima sin sesión (solicita acceso), con correo
   no permitido (denegado) y correo permitido (abre la app). Si alguna ruta
   entrega assets anónimamente, bloquearla antes de subir el build. No usar
   previews de Firebase Hosting para testers privados.
   Descargar el artefacto privado, extraerlo en `build/web/` junto a
   `deploy/beta/`, construir la imagen con
   `docker build -f deploy/beta/Dockerfile .` y desplegar una revisión del
   servicio ya protegido en el puerto 8080. El `try_files` del servidor sirve
   rutas Flutter y sus assets; IAP controla todo el servicio antes de llegar a
   nginx. Fijar revisión/imagen por digest y registrar quién aprobó el acceso.
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
Chrome sin sesión. Una URL de Firebase Hosting por sí sola no equivale a
privacidad; tampoco basta que el repositorio sea privado. Al pasar al origen
público comercial, los datos guardados en el origen beta no se transfieren:
el profesional exporta backup cifrado y lo restaura en el origen nuevo.

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
2. Adaptar la función comercial ya desplegada en Pro si la auditoría confirma
   aislamiento por producto; en otro caso usar una función mínima en el mismo
   proyecto. Recibir webhook firmado, verificar firma sobre cuerpo original,
   producto/variante, idempotencia de eventos y estados pagado/reembolso;
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
| Núcleo Chrome | UI Flutter, pacientes, metas, semanas, PDF, catálogo fijo y backup | QA observado en Chrome y beta en Cloud Run con IAP |
| Catálogo | USDA 2026-04 y alimentos profesionales separados | Nombres/medidas regionales con evidencia y release aprobado |
| Semana larga | Copiar días/comidas, resumen y lista de compras por gramos | Sustituciones guiadas y medición de tiempo real |
| Licencia | Decisión comercial documentada | Producto Lemon, backend firmado, recuperación, términos |
| Seguridad | Datos locales y backup cifrado disponible | Auditoría de hosting, actualización de assets y comportamiento sin red |
