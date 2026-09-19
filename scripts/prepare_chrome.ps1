$ErrorActionPreference = "Stop"

function Assert-LastExitCode([string]$StepName) {
  if ($LASTEXITCODE -ne 0) {
    throw "$StepName fallo con codigo $LASTEXITCODE"
  }
}

Write-Host "== Nutrikuaa Nutri: preparando entorno Chrome ==" -ForegroundColor Cyan
flutter --version
Assert-LastExitCode "flutter --version"

flutter pub get
Assert-LastExitCode "flutter pub get"

Write-Host "Actualizando runtime SQLite Web..." -ForegroundColor Cyan
if (Test-Path "web/sqlite3.wasm") { Remove-Item "web/sqlite3.wasm" -Force }
if (Test-Path "web/sqflite_sw.js") { Remove-Item "web/sqflite_sw.js" -Force }

dart run sqflite_common_ffi_web:setup --force
Assert-LastExitCode "SQLite Web setup"

if (-not (Test-Path "web/sqlite3.wasm")) {
  throw "No se genero web/sqlite3.wasm"
}
if (-not (Test-Path "web/sqflite_sw.js")) {
  throw "No se genero web/sqflite_sw.js"
}

flutter analyze --no-fatal-infos --no-fatal-warnings
Assert-LastExitCode "flutter analyze"

Write-Host ""
Write-Host "Entorno listo." -ForegroundColor Green
Write-Host "Ejecuta:" -ForegroundColor Yellow
Write-Host "flutter run -d chrome --web-port 8080"
