# preToolUse — compte CallMcpTool librarian (chemin fiable terrain Cursor)
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_hook-io.ps1')
try {
    $raw = Read-HookInput
    if ([string]::IsNullOrWhiteSpace($raw)) { Out-Allow }
    try { $in = $raw | ConvertFrom-Json } catch { Out-Allow }

    $tool = [string]$in.tool_name
    if ($tool -ne 'CallMcpTool') { Out-Allow }

    $isLibrarian = $false
    $ti = $in.tool_input
    if ($ti) {
        $srv = ''
        if ($ti.PSObject.Properties['server']) { $srv = [string]$ti.server }
        $tn = ''
        if ($ti.PSObject.Properties['toolName']) { $tn = [string]$ti.toolName }
        if ($srv -match 'librarian') { $isLibrarian = $true }
        if ($tn -match '^library_') { $isLibrarian = $true }
    }
    if (-not $isLibrarian -and $raw -match 'librarian|library_traverse|library_read|library_search|library_shortest_path|library_graph') {
        $isLibrarian = $true
    }
    if ($isLibrarian) {
        $root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { (Get-Location).Path })
        Record-LibrarianCall $root
    }
    Out-Allow
} catch { Out-Allow }
