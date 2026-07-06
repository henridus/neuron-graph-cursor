# gate-shell-bootstrap.ps1 — V14 strict maintenance gate
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_hook-io.ps1')
$raw = Read-HookInput
$root = Get-ProjectRoot (Get-Location).Path
$cmd = ''
if (-not [string]::IsNullOrWhiteSpace($raw)) {
    try {
        $in = $raw | ConvertFrom-Json
        $cmd = Get-ShellCommand $in
        if ($in.cwd) { $root = Get-ProjectRoot $in.cwd }
    } catch { }
}
if ([string]::IsNullOrWhiteSpace($cmd)) { Out-Deny 'Commande maintenance absente' 'beforeShellExecution doit fournir command.' }
if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { Out-Allow }
if (Test-ShellMaintenanceAllow $cmd) {
    if ($cmd -match 'record-reflection-proof|record-terrain-test|PREP_TERRAIN|RUN_TERRAIN_BOOTSTRAP') { Out-Allow }
    if (Test-GovernanceUnlock $root '.cursor\hooks.json') { Out-Allow }
    Out-Deny 'Unlock gouvernance requis' 'Maintenance shell exige unlock externe.'
}
Out-Deny 'Commande maintenance non autorisee' 'Matcher bootstrap reserve aux scripts maintenance.'
