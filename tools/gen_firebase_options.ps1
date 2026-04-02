$ErrorActionPreference="Stop"
$root=Get-Location
if (!(Test-Path (Join-Path $root "pubspec.yaml"))) { throw "pubspec.yaml_not_found" }

$flutterfire=(Get-Command flutterfire -ErrorAction SilentlyContinue)
if (-not $flutterfire) {
  dart pub global activate flutterfire_cli | Out-Host
  $env:PATH = $env:PATH + ";" + (Join-Path $env:LOCALAPPDATA "Pub\Cache\bin")
}

flutterfire configure --project=sirdas-20e97 --platforms=web,android --out=lib\firebase_options.dart
