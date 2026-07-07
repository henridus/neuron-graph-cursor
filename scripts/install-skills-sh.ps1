# install-skills-sh.ps1 — skills.sh fleet V10 (tunnel requis)
param([string]$AgentPath = (Get-Location).Path)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\.cursor\hooks\_hook-io.ps1')
if (-not (Test-BrainTunnelOk $AgentPath)) {
    throw 'Tunnel cerveau incomplet — lire requiredReads vault + spec ou MDC avant install-skills.'
}
Push-Location $AgentPathtry {
    $adds = @(
        'vercel-labs/skills@find-skills',
        'mattpocock/skills@triage',
        'mattpocock/skills@diagnosing-bugs',
        'anthropics/skills@skill-creator',
        'anthropics/skills@xlsx',
        'anthropics/skills@pdf'
    )
    foreach ($pkg in $adds) {
        Write-Host "[skills.sh] $pkg" -ForegroundColor Cyan
        npx --yes skills@latest add $pkg -a cursor -y --copy 2>&1 | Out-Host
    }
    Write-Host '[OK] skills.sh fleet' -ForegroundColor Green
} finally { Pop-Location }
