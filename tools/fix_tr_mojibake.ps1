param(
  [string]$Root = (Get-Location).Path
)

function Should-Skip([string]$full) {
  $p = $full.ToLowerInvariant()
  return ($p -match '\\build\\') -or
         ($p -match '\\\.dart_tool\\') -or
         ($p -match '\\\.idea\\') -or
         ($p -match '\\android\\\.gradle\\') -or
         ($p -match '\\admin_web\\build\\') -or
         ($p -match '\\functions\\node_modules\\')
}

function Fix-Line([string]$line) {
  if ($line -notmatch "[\u00C3\u00C4\u00C5]") { return $line }
  $cur = $line
  for ($i=0; $i -lt 4; $i++) {
    if ($cur -notmatch "[\u00C3\u00C4\u00C5]") { break }
    $latin1 = [System.Text.Encoding]::GetEncoding("ISO-8859-1").GetBytes($cur)
    $cur = [System.Text.Encoding]::UTF8.GetString($latin1)
  }
  return $cur
}

$exts = @(".dart",".yaml",".yml",".json",".arb",".txt",".md")

$files = Get-ChildItem -Path $Root -Recurse -File | Where-Object {
  $exts -contains $_.Extension.ToLowerInvariant()
} | Where-Object {
  -not (Should-Skip $_.FullName)
}

foreach ($f in $files) {
  $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
  if ($raw -notmatch "[\u00C3\u00C4\u00C5]") { continue }

  $lines = $raw -split "`n", 0, "SimpleMatch"
  $changed = $false
  for ($j=0; $j -lt $lines.Length; $j++) {
    $orig = $lines[$j]
    $fixed = Fix-Line $orig
    if ($fixed -ne $orig) {
      $lines[$j] = $fixed
      $changed = $true
    }
  }

  if ($changed) {
    $out = ($lines -join "`n")
    Set-Content -LiteralPath $f.FullName -Value $out -Encoding UTF8
    Write-Host ("Fixed: " + $f.FullName)
  }
}
