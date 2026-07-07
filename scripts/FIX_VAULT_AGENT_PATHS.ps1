# FIX_VAULT_AGENT_PATHS.ps1 — corrige dossier Host/judit dans agents/*.md (vault)
param(
    [string]$VaultPath = 'C:\Users\henri\OneDrive\Obsidian\AgentMemory'
)
$ErrorActionPreference = 'Stop'
$agentsDir = Join-Path $VaultPath 'agents'
if (-not (Test-Path $agentsDir)) { throw "agents absent: $agentsDir" }
$fixed = @()
Get-ChildItem $agentsDir -Filter '*.md' | ForEach-Object {
    $raw = Get-Content $_.FullName -Raw -Encoding UTF8
    $new = $raw
    $new = $new -replace 'C:\\Users\\Host\\OneDrive\\27_IA', 'C:\Users\henri\OneDrive\27_IA'
    $new = $new -replace 'C:\\Users\\judit\\OneDrive\\27_IA', 'C:\Users\henri\OneDrive\27_IA'
    if ($new -ne $raw) {
        Set-Content $_.FullName $new -Encoding UTF8 -NoNewline
        $fixed += $_.Name
    }
}
Write-Host ("FIXED dossier paths: " + ($fixed -join ', '))
if ($fixed.Count -eq 0) { Write-Host 'SKIP aucun dossier Host/judit' }
