$ErrorActionPreference="Stop"
$root=Get-Location
Set-Location (Join-Path $root "admin_web")
flutter pub get | Out-Host
flutter build web --release | Out-Host
Set-Location $root
powershell -ExecutionPolicy Bypass -File .\tools\patch_firebase_hosting_admin.ps1
firebase deploy --only hosting:admin
