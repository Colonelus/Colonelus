$ErrorActionPreference="Stop"
$root=Get-Location
$main=Join-Path $root "lib\main.dart"
if (!(Test-Path $main)) { throw "main.dart_not_found" }
$c=Get-Content $main -Raw

function EnsureImport([string]$content,[string]$importLine){
  if ($content -match [regex]::Escape($importLine)) { return $content }
  $m=[regex]::Match($content,"(^\s*import\s+['""][^'""]+['""];\s*\r?\n)+", [System.Text.RegularExpressions.RegexOptions]::Multiline)
  if ($m.Success) {
    return $content.Insert($m.Index + $m.Length, $importLine + "`r`n")
  }
  return $importLine + "`r`n" + $content
}

$c=EnsureImport $c "import 'package:sirdas_yeni/bootstrap/usage_bootstrap.dart';"

if ($c -notmatch "setupUsageBootstrap\(\);") {
  $m=[regex]::Match($c,"await\s+Firebase\.initializeApp\([^;]*\);\s*", [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($m.Success) {
    $insertAt=$m.Index + $m.Length
    $c=$c.Insert($insertAt,"setupUsageBootstrap();`r`n")
  } else {
    $m=[regex]::Match($c,"void\s+main\s*\(\s*\)\s*async\s*\{\s*", [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if ($m.Success) {
      $insertAt=$m.Index + $m.Length
      $c=$c.Insert($insertAt,"setupUsageBootstrap();`r`n")
    } else {
      throw "main_function_not_found"
    }
  }
}

Set-Content -Path $main -Value $c -NoNewline -Encoding UTF8
