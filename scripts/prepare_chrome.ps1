$ErrorActionPreference = "Stop"

Write-Host "== Nutrikuaa Nutri: preparando entorno Chrome ==" -ForegroundColor Cyan

flutter pub get
dart run sqflite_common_ffi_web:setup --force
flutter analyze --no-fatal-infos --no-fatal-warnings

Write-Host ""
Write-Host "Entorno listo." -ForegroundColor Green
Write-Host "Ejecuta:" -ForegroundColor Yellow
Write-Host "flutter run -d chrome --web-port 8080"
