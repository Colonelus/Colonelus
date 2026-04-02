$ErrorActionPreference="Stop"
$root=Get-Location
$rules=Join-Path $root "firestore.rules"
$add=Join-Path $root "firestore.rules.admin_additions"
if (!(Test-Path $add)) { throw "admin_additions_missing" }
if (!(Test-Path $rules)) { throw "firestore.rules_not_found" }
$c=Get-Content $rules -Raw
$a=Get-Content $add -Raw

if ($c -match "function isAdmin\(\)") { exit 0 }

$idx=$c.LastIndexOf("}")
if ($idx -lt 0) { throw "rules_format_error" }
$c2=$c.Substring(0,$idx) + "`r`n" + $a + "`r`n" + $c.Substring($idx)

Set-Content -Path $rules -Value $c2 -NoNewline -Encoding utf8
