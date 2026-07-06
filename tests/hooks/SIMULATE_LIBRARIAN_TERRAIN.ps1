# SIMULATE_LIBRARIAN_TERRAIN.ps1 — simule CallMcpTool pour valider librarian_calls
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$hooks = Join-Path $root '.cursor\hooks'
$pretool = Join-Path $hooks 'track-librarian-pretool.ps1'
$gatesPath = Join-Path $root '.cursor\agent-gates.json'
if (-not (Test-Path $pretool)) { Write-Host "FAIL pretool absent"; exit 1 }

. (Join-Path $hooks '_hook-io.ps1')
Write-Gates $root @{ librarian_used = $false; librarian_calls = 0 }

function Invoke-Pretool([hashtable]$payload) {
    $j = $payload | ConvertTo-Json -Depth 6 -Compress
    $env:CURSOR_HOOK_TEST_INPUT = $j
    & $pretool | Out-Null
    Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
}

Invoke-Pretool @{
    tool_name = 'CallMcpTool'
    tool_input = @{
        server = 'user-librarian'
        toolName = 'library_traverse'
        arguments = @{ start = 'MAP-padel'; depth = 1 }
    }
    cwd = $root
}
Invoke-Pretool @{
    tool_name = 'CallMcpTool'
    tool_input = @{
        server = 'user-librarian'
        toolName = 'library_read'
        arguments = @{ path = 'erreurs/padel.md' }
    }
    cwd = $root
}

$g = Get-Content $gatesPath -Raw | ConvertFrom-Json
$calls = 0
if ($null -ne $g.librarian_calls) { try { $calls = [int]$g.librarian_calls } catch { } }
if ($g.librarian_used -ne $true -or $calls -lt 2) {
    Write-Host "FAIL librarian_used=$($g.librarian_used) calls=$calls attendu >= 2"
    exit 1
}
Write-Host "PASS SIMULATE_LIBRARIAN_TERRAIN calls=$calls"
exit 0
