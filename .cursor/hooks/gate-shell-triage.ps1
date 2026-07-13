# beforeShellExecution V20 — tunnel requis pour shell mutate (E1/E4), fail-open sinon
$ErrorActionPreference = 'SilentlyContinue'
if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { '{"permission":"allow"}' | Write-Output; exit 0 }
try {
    . (Join-Path $PSScriptRoot '_hook-io.ps1')
    $raw = Read-HookInput
    $root = Get-ProjectRoot (Get-Location).Path
    $cmd = ''
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $in = $raw | ConvertFrom-Json; $root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { $root }); $cmd = Get-ShellCommand $in } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($cmd)) { Out-Allow }
    if (Test-ShellRecoveryEntrypoint $cmd) { Out-Allow }
    if (Test-ShellMaintenanceAllow $cmd) { Out-Allow }
    if (Test-ShellAllowWithoutTriage $cmd) { Out-Allow }
    $manip = Test-ShellManipulatesEnforcement $cmd
    if (-not (Test-ShellMutatesFile $cmd) -and -not $manip) { Out-Allow }
    if (-not (Test-BrainActive $root)) { Out-Deny 'Brain non charge' 'sessionStart requis.' }
    # V20: restore tunnel Read session (juste milieu V17)
    if (-not (Test-BrainTunnelOk $root)) { Out-Deny 'Tunnel cerveau incomplet' 'Lire requiredReads vault avant Shell.' }
    if (-not (Test-BrainOkLoaded $root)) { Out-Deny 'Brain non charge' 'Attendre injection cerveau.' }
    Out-Allow
} catch { '{"permission":"allow"}' | Write-Output; exit 0 }
