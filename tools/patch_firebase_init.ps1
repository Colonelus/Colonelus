$ErrorActionPreference="Stop"
$root=Get-Location
$main=Join-Path $root "lib\main.dart"
if (!(Test-Path $main)) { throw "main.dart_not_found" }
$c=Get-Content $main -Raw

function EnsureImport([string]$content,[string]$importLine){
  if ($content -match [regex]::Escape($importLine)) { return $content }
  $m=[regex]::Match($content,"(^\s*import\s+['""][^'""]+['""];\s*\r?\n)+", [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($m.Success) { return $content.Insert($m.Index + $m.Length, $importLine + "`r`n") }
  return $importLine + "`r`n" + $content
}

$c=EnsureImport $c "import 'package:firebase_core/firebase_core.dart';"
$c=EnsureImport $c "import 'firebase_options.dart';"

$c=[regex]::Replace($c,"Firebase\.initializeApp\s*\(\s*\)","Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)")

Set-Content -Path $main -Value $c -NoNewline -Encoding UTF8
