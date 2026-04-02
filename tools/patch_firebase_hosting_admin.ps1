$ErrorActionPreference="Stop"
$root=Get-Location
$firebaseJson=Join-Path $root "firebase.json"
$cfg=@{}
if (Test-Path $firebaseJson) {
  $cfg=Get-Content $firebaseJson -Raw | ConvertFrom-Json
} else {
  $cfg=@{}
}
if ($null -eq $cfg.hosting) { $cfg | Add-Member -NotePropertyName hosting -NotePropertyValue @() }
$hosting=$cfg.hosting
if ($hosting -isnot [System.Collections.IList]) { $hosting=@($hosting) }

$found=$false
for ($i=0; $i -lt $hosting.Count; $i++) {
  if ($hosting[$i].target -eq "admin") { $found=$true; break }
}
if (-not $found) {
  $hosting += [pscustomobject]@{
    target="admin"
    public="admin_web/build/web"
    ignore=@("firebase.json","**/.*","**/node_modules/**")
    rewrites=@(@{ source="**"; destination="/index.html" })
  }
}
$cfg.hosting=$hosting
$cfg | ConvertTo-Json -Depth 20 | Set-Content -Encoding utf8 -NoNewline $firebaseJson
