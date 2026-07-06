# stop V05 - handoff Obsidian seulement (pas de relance auto)
# Le followup_message V04 relancait l'agent en boucle ; handoff reste, relance supprimee.
$ErrorActionPreference = 'SilentlyContinue'
$hookPipeline = ''
if ($input) {
    $parts = @($input | ForEach-Object { [string]$_ })
    if ($parts.Count -gt 0) { $hookPipeline = ($parts -join "`n").Trim() }
}
. (Join-Path $PSScriptRoot '_hook-io.ps1')
$inputRaw = if (-not [string]::IsNullOrWhiteSpace($hookPipeline)) { Select-HookJsonPayload $hookPipeline } else { Read-HookInput }
if ([string]::IsNullOrWhiteSpace($inputRaw)) { exit 0 }

$hookPath = Join-Path $PSScriptRoot 'brain-handoff.ps1'
if (Test-Path $hookPath) {
    $inputRaw | & powershell -NoProfile -ExecutionPolicy Bypass -File $hookPath | Out-Null
}
exit 0
