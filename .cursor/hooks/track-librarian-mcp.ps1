# beforeMCPExecution V18 — marque appels librarian dans agent-gates
$ErrorActionPreference = 'SilentlyContinue'
$hookPipeline = ''
if ($input) {
    $parts = @($input | ForEach-Object { [string]$_ })
    if ($parts.Count -gt 0) { $hookPipeline = ($parts -join "`n").Trim() }
}
try {
    . (Join-Path $PSScriptRoot '_hook-io.ps1')
    $raw = if (-not [string]::IsNullOrWhiteSpace($hookPipeline)) { Select-HookJsonPayload $hookPipeline } else { Read-HookInput }
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    try { $in = $raw | ConvertFrom-Json } catch { exit 0 }

    $server = ''
    $tool = ''
    if ($in.mcp_server) { $server = [string]$in.mcp_server }
    elseif ($in.server) { $server = [string]$in.server }
    elseif ($in.mcpServer) { $server = [string]$in.mcpServer }
    if ($in.tool_name) { $tool = [string]$in.tool_name }
    elseif ($in.name) { $tool = [string]$in.name }
    elseif ($in.toolName) { $tool = [string]$in.toolName }

    $isLibrarian = $false
    if ($server -match 'librarian') { $isLibrarian = $true }
    if ($tool -match '^library_') { $isLibrarian = $true }
    if (-not $isLibrarian -and $raw -match 'librarian|library_traverse|library_read|library_search|library_shortest_path|library_graph') {
        $isLibrarian = $true
    }

    if (-not $isLibrarian) { exit 0 }

    $root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { (Get-Location).Path })
    Record-LibrarianCall $root
} catch { }
exit 0
