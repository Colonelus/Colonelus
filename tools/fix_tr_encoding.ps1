$ErrorActionPreference="Stop"
$root=Get-Location
$py=(Get-Command python -ErrorAction SilentlyContinue)
if (-not $py) { throw "python_not_found" }
python .\tools\fix_tr_encoding.py
