# beforeShellExecution — deny flash sans selftest marker (MDC 84)
# Domaine: homelab | Spec: specs/052-homelab-pi-flash/spec.md

$ErrorActionPreference = 'Stop'
$hookPipeline = ''
if ($input) {
    $parts = @($input | ForEach-Object { [string]$_ })
    if ($parts.Count -gt 0) { $hookPipeline = ($parts -join "`n").Trim() }
}
. (Join-Path $PSScriptRoot '_hook-io.ps1')
$inputRaw = if (-not [string]::IsNullOrWhiteSpace($hookPipeline)) { Select-HookJsonPayload $hookPipeline } else { Read-HookInput }
if ([string]::IsNullOrWhiteSpace($inputRaw)) { exit 0 }

try { $payload = $inputRaw | ConvertFrom-Json } catch { exit 0 }
$cmd = ''
if ($payload.command) { $cmd = [string]$payload.command }
elseif ($payload.tool_input.command) { $cmd = [string]$payload.tool_input.command }
else { $cmd = $inputRaw }

$cmdLower = $cmd.ToLower()
$projectRoot = Get-Location
$markerPath = Join-Path $projectRoot '.cursor\state\homelab-selftest-pass'

function Deny-Flash($msg) {
    @{ permission = 'deny'; user_message = $msg } | ConvertTo-Json -Compress
    exit 0
}

function Allow-Cmd {
    @{ permission = 'allow' } | ConvertTo-Json -Compress
    exit 0
}

# Always allow selftest and safe ops
if ($cmdLower -match 'run_homelab_selftest|selftest_|audit_sd_boot|wait_and_finish_pi|-whatif') {
    Allow-Cmd
}

# Skip gate only for explicit user override (never agent)
if ($cmdLower -match '-skipselftestgate') {
    Allow-Cmd
}

$isFlash = $cmdLower -match 'go_pi_sd|flash_pi_sd|rpi-imager|physicaldrivenumber'
$isBootPatch = $cmdLower -match 'user-data|network-config' -and $cmdLower -match 'boot|fat|partition'

if (-not $isFlash -and -not $isBootPatch) {
    Allow-Cmd
}

$markerValid = $false
if (Test-Path $markerPath) {
    $age = (Get-Date) - (Get-Item $markerPath).LastWriteTime
    if ($age.TotalHours -lt 1) { $markerValid = $true }
}

if (-not $markerValid) {
    Deny-Flash 'FLASH BLOQUE: RUN_HOMELAB_SELFTEST.ps1 PASS requis (< 1h). Marker: .cursor/state/homelab-selftest-pass. Spec 052 + MDC 84.'
}

if ($isBootPatch) {
    Deny-Flash 'PATCH MANUEL SD interdit. Reflash complet via GO_PI_SD.ps1 (MDC 84 P3).'
}

Allow-Cmd
