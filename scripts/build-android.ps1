$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$jdkHome = Get-ChildItem -LiteralPath (Join-Path $projectRoot '.tools\jdk21') -Directory | Select-Object -First 1 -ExpandProperty FullName
if (-not $jdkHome) { throw 'JDK 21 não encontrado em .tools\jdk21.' }
$env:JAVA_HOME = $jdkHome
$env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME

Push-Location $projectRoot
try {
  node scripts/build-mobile.mjs
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar os arquivos web.' }
  npx cap sync android
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao sincronizar o projeto Android.' }
  Push-Location (Join-Path $projectRoot 'android')
  try {
    .\gradlew.bat assembleDebug
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o APK.' }
  } finally { Pop-Location }
  $releaseDir = Join-Path $projectRoot 'releases'
  New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
  Copy-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'Aura67Build\app\outputs\apk\debug\app-debug.apk') -Destination (Join-Path $releaseDir 'Aura67-v0.1.0-debug.apk') -Force
  Write-Host 'APK criado em releases\Aura67-v0.1.0-debug.apk'
} finally { Pop-Location }
