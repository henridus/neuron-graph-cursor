# record-brain-reads.ps1 — V14 observabilite uniquement
param(
    [string]$AgentPath = (Get-Location).Path,
    [switch]$MarkSpec
)
$ErrorActionPreference = 'Stop'
. (Join-Path $AgentPath '.cursor\hooks\_hook-io.ps1')
$AgentPath = (Resolve-Path $AgentPath).Path
if (-not (Test-Path (Join-Path $AgentPath 'AGENTS.md'))) {
    Write-Error 'Lancer depuis racine agent (AGENTS.md requis).'
}
$proof = Read-ReadProof $AgentPath
$count = if ($proof -and $proof.reads) { @($proof.reads).Count } else { 0 }
Write-Host "OBS read-proof entries=$count"
