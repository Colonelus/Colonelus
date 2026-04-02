$ErrorActionPreference="Stop"
$root=Get-Location
Set-Location (Join-Path $root "admin_web")
$flutterfire=(Get-Command flutterfire -ErrorAction SilentlyContinue)
if (-not $flutterfire) {
  dart pub global activate flutterfire_cli | Out-Host
  $env:PATH = $env:PATH + ";" + (Join-Path $env:LOCALAPPDATA "Pub\Cache\bin")
}
flutterfire configure --project=sirdas-20e97 --platforms=web --out=lib\firebase_options.dart
