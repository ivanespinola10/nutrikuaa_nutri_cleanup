# Acceso controlado para testers — beta web

Esta beta es para **pacientes ficticios**. El login y la lista de invitados
controlan el uso normal de la interfaz y registran accesos; Hosting continúa
sirviendo los archivos estáticos a cualquiera que conozca la URL. La base
local del navegador no está cifrada. No usar datos de salud reales ni
considerar el login un mecanismo de custodia de expedientes clínicos.

## Configuración inicial (proyecto `nutrikuaa-nutri`)

1. En Firebase Console, entrar al proyecto **nutrikuaa-nutri**. En
   Authentication → Sign-in method, habilitar **Email/Password**. No hay
   formulario de alta pública en NutriKuaa.
2. Authentication → Settings → Authorized domains: verificar
   `nutrikuaa-nutri.web.app` y `localhost` para Chrome local. Si se usa otro
   dominio, añadirlo. Configurar la plantilla del correo de restablecimiento.
3. Crear Cloud Firestore en modo producción. En el proyecto correcto, desplegar
   `firestore.rules` antes de enviar invitaciones:

   ```powershell
   firebase deploy --only firestore:rules --project nutrikuaa-nutri
   ```

   Esto sustituye las reglas Firestore del proyecto **nutrikuaa-nutri**. Revisar
   primero si el proyecto ya tiene otras colecciones que deban conservar acceso.
4. Configuración del proyecto → Tus apps: registrar una **app web** en ese
   proyecto, sin activar Analytics. Copiar `apiKey`, `appId` y
   `messagingSenderId` a un archivo local llamado `tester_firebase.local.json`
   a partir de `tester_firebase.example.json`. Cambiar el correo de contacto
   por uno **real y atendido**. No publicar un aviso con un contacto ficticio.
   La configuración web de Firebase no es una contraseña; no agregar cuentas
   administrativas o claves de servicio al repositorio.
5. Authentication → Users: crear una cuenta Email/Password para **cada**
   persona invitada. Identificar el UID creado. Firestore → `testers` → crear
   un documento cuyo ID sea ese UID, con `approved` (boolean) = `true`.
   Opcionalmente guardar `name` o `cohort` para ordenar el listado. No guardar
   datos de pacientes en esta colección. Cada tester debe cambiar su clave
   mediante **Recuperar acceso** en el login.
6. Comprobar con un tester invitado y otro usuario no aprobado. El segundo
   podrá autenticarse si tiene cuenta, pero verá acceso denegado y no podrá
   escribir registros en Firestore.

## VS Code / Chrome

```powershell
git fetch origin
git switch --track origin/codex/nutri-tester-access-20260930
Copy-Item tester_firebase.example.json tester_firebase.local.json
# Rellenar tester_firebase.local.json con los valores del proyecto y el correo.
flutter pub get
dart run tools/setup_sqlite_web.dart
flutter run -d chrome --web-port 8080 --dart-define-from-file=tester_firebase.local.json
```

Si la rama ya existe localmente, usar `git switch codex/nutri-tester-access-20260930`
y `git pull --ff-only`. Para compilar, usar el mismo parámetro:

```powershell
flutter build web --release --dart-define-from-file=tester_firebase.local.json
```

Con la configuración lista y tras aprobar el resultado en Chrome:

```powershell
firebase deploy --only hosting:nutri --project nutrikuaa-nutri
```

Ese comando reemplaza la web publicada. No ejecutarlo hasta decidir abrir la
beta. El código en la PR no cambia la web por sí solo.

## Lista y revocación

- Authentication → Users: listado de cuentas y correos. Firestore → `testers`:
  estado `approved`. `tester_consents/{uid}/versions/beta-2026-09-30-v1`:
  fecha de aceptación. `tester_activity/{uid}`: última entrada completada.
  El correo queda en Authentication; Firestore sólo conserva UID, aprobación,
  versión de consentimiento y marcas de tiempo.
- Para revocar, poner `approved = false`; la sesión con conexión activa deja
  de mostrar el programa. También se puede deshabilitar la cuenta en Auth.
  Una pestaña desconectada o archivos locales del dispositivo no pueden
  borrarse remotamente con este diseño.
- El registro indica quién aceptó y abrió la app. No registra tareas, tiempo
  de uso, pacientes, PDF ni feedback; recoger sugerencias por otro canal.
- Usar **un perfil de Chrome distinto por tester**. La app bloquea una cuenta
  diferente en el mismo perfil tras un primer acceso, pues la base local tiene
  un nombre compartido y no se elimina al cerrar sesión.
- El profesional puede borrar sus registros locales en Chrome y las copias
  exportadas por separado. Para solicitudes de eliminación de cuenta y
  registros de acceso, atender el correo indicado en la invitación.

## Política y límites

El texto visible en `TesterAccessPolicy` es una versión de trabajo de las
condiciones de una beta. Actualizar versión, texto y reglas si cambia el
tratamiento; cada tester volverá a aceptar. Revisarlo jurídicamente según los
mercados antes de cargar datos reales o vender licencias. Inventariar tráfico,
cookies y almacenamiento de la versión desplegada antes de hacer afirmaciones
absolutas. El login de testers es separado de la futura activación de una
licencia de compra única con Lemon Squeezy.
