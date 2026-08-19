$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$jdkHome = Get-ChildItem -LiteralPath (Join-Path $projectRoot '.tools\jdk21') -Directory | Select-Object -First 1 -ExpandProperty FullName
if (-not $jdkHome) { throw 'JDK 21 não encontrado em .tools\jdk21.' }
$env:JAVA_HOME = $jdkHome
$env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$assetStage = $null

Push-Location $projectRoot
try {
  node scripts/build-mobile.mjs
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar os arquivos web.' }
  npx cap sync android
  if ($LASTEXITCODE -ne 0) { throw 'Falha ao sincronizar o projeto Android.' }
  $generatedKeep = Join-Path $projectRoot 'android\capacitor-cordova-android-plugins\src\main\res\.gitkeep'
  if (Test-Path -LiteralPath $generatedKeep) { Remove-Item -LiteralPath $generatedKeep -Force }
  $generatedJavaKeep = Join-Path $projectRoot 'android\capacitor-cordova-android-plugins\src\main\java\.gitkeep'
  if (Test-Path -LiteralPath $generatedJavaKeep) { Remove-Item -LiteralPath $generatedJavaKeep -Force }
  $localBuildRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Aura67Build'))
  $assetStage = [IO.Path]::GetFullPath((Join-Path $localBuildRoot ("android-assets-" + $PID)))
  if (-not $assetStage.StartsWith($localBuildRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Diretório temporário Android inválido.' }
  New-Item -ItemType Directory -Force -Path $assetStage | Out-Null
  Copy-Item -Path (Join-Path $projectRoot 'android\app\src\main\assets\*') -Destination $assetStage -Recurse -Force
  $env:AURA_ANDROID_ASSETS = $assetStage
  Push-Location (Join-Path $projectRoot 'android')
  try {
    .\gradlew.bat assembleDebug
    if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o APK.' }
  } finally { Pop-Location }
  $releaseDir = Join-Path $projectRoot 'releases'
  New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
  Copy-Item -LiteralPath (Join-Path $env:LOCALAPPDATA 'Aura67Build\app\outputs\apk\debug\app-debug.apk') -Destination (Join-Path $releaseDir 'Aura67-v0.2.1-debug.apk') -Force
  Write-Host 'APK criado em releases\Aura67-v0.2.1-debug.apk'
} finally {
  Pop-Location
  if ($assetStage -and (Test-Path -LiteralPath $assetStage)) {
    $checkedStage = [IO.Path]::GetFullPath($assetStage)
    $checkedRoot = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'Aura67Build'))
    if ($checkedStage.StartsWith($checkedRoot + [IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $checkedStage -Recurse -Force }
  }
}
