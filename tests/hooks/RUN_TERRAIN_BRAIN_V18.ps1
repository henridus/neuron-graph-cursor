# RUN_TERRAIN_BRAIN_V18.ps1 - OBSOLETE (supersede par V20).
# V19 avait abandonne le tunnel ; V20 l a restaure (juste milieu V17).
# Delegue a RUN_TERRAIN_BRAIN_V20.ps1 pour ne pas faire echouer la propagation.
$ErrorActionPreference = 'SilentlyContinue'
$v20 = Join-Path $PSScriptRoot 'RUN_TERRAIN_BRAIN_V20.ps1'
if (-not (Test-Path $v20)) {
    Write-Host 'SKIP V18: RUN_TERRAIN_BRAIN_V20.ps1 absent'
    exit 0
}
Write-Host 'V18 obsolete -> delegue a V20 (tunnel restaure)'
& powershell -NoProfile -ExecutionPolicy Bypass -File $v20
exit $LASTEXITCODE
