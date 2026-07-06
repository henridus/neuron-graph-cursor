# preToolUse V08 — marque WebSearch/WebFetch dans reflection-proof
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_hook-io.ps1')

try {
    $raw = Read-HookInput
    if ([string]::IsNullOrWhiteSpace($raw)) { Out-Allow }

    try { $in = $raw | ConvertFrom-Json } catch { Out-Allow }

    $tool = $in.tool_name
    if ($tool -notin @('WebSearch', 'WebFetch')) { Out-Allow }

    $root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { (Get-Location).Path })
    Update-ReflectionExternal $root @{ web = $true }
    Out-Allow
}
catch {
    Out-Allow
}
