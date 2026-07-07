# FIX_AGENTS_MD_PATHS.ps1 — corrige judit/Host dans AGENTS.md (fleet)
param(
    [string]$FleetRoot = 'C:\Users\henri\OneDrive\27_IA\00_Cursor'
)
$ErrorActionPreference = 'Stop'
$fixed = @()
Get-ChildItem $FleetRoot -Directory | ForEach-Object {
    $ag = Join-Path $_.FullName 'AGENTS.md'
    if (-not (Test-Path $ag)) { return }
    $raw = Get-Content $ag -Raw -Encoding UTF8
    $new = $raw
    $new = $new -replace 'C:\\Users\\judit\\OneDrive', 'C:\Users\henri\OneDrive'
    $new = $new -replace 'C:\\Users\\Host\\OneDrive', 'C:\Users\henri\OneDrive'
    if ($new -ne $raw) {
        Set-Content $ag $new -Encoding UTF8 -NoNewline
        $fixed += $_.Name
    }
}
Write-Host ("FIXED AGENTS.md: " + ($fixed -join ', '))
if ($fixed.Count -eq 0) { Write-Host 'SKIP aucun judit/Host dans AGENTS.md' }
