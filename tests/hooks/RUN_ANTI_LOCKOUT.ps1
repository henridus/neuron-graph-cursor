# RUN_ANTI_LOCKOUT.ps1 — palier S2 anti-lockout (labo)
param([string]$AgentPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path)
$ErrorActionPreference = 'Stop'
Push-Location $AgentPath
. (Join-Path $AgentPath '.cursor\hooks\_hook-io.ps1')
$Hooks = Join-Path $AgentPath '.cursor\hooks'
$fail = 0

function IG($json) {
    $env:CURSOR_HOOK_TEST_INPUT = $json
    $out = & (Join-Path $Hooks 'gate-write-unified.ps1') 2>&1
    $code = $LASTEXITCODE
    Remove-Item Env:CURSOR_HOOK_TEST_INPUT -EA SilentlyContinue
    @{ out = ($out | Out-String).Trim(); code = $code; deny = ($code -eq 2) }
}

Write-Host '=== S2.1 cold gates deny foo.txt ==='
Reset-SessionReads $AgentPath
$foo = Join-Path $AgentPath 'foo-lockout-test.txt'
'x' | Set-Content $foo -Encoding UTF8
$r1 = IG (@{ tool_name = 'Write'; tool_input = @{ path = $foo; contents = 'y' }; cwd = $AgentPath } | ConvertTo-Json -Compress)
if (-not $r1.deny) { Write-Host 'FAIL S2.1'; $fail++ } else { Write-Host 'PASS S2.1' }

Write-Host '=== S2.2 RECOVERY_UNLOCK restores tunnel + unlock ==='
& (Join-Path $AgentPath 'scripts\RECOVERY_UNLOCK_AGENT.ps1') | Out-Null
$g = Read-Gates $AgentPath
if ($g.brain_tunnel_ok -ne $true) { Write-Host 'FAIL S2.2'; $fail++ } else { Write-Host 'PASS S2.2' }

Write-Host '=== S2.3 deny hooks edit sans tunnel ==='
Reset-SessionReads $AgentPath
$hookTarget = Join-Path $AgentPath '.cursor\hooks\gate-write-unified.ps1'
$r3 = IG (@{ tool_name = 'Write'; tool_input = @{ path = $hookTarget; contents = '# hacked' }; cwd = $AgentPath } | ConvertTo-Json -Compress)
if (-not $r3.deny) { Write-Host 'FAIL S2.3'; $fail++ } else { Write-Host 'PASS S2.3' }

$report = Join-Path $AgentPath 'reports\ANTI_LOCKOUT_S2.md'
@(
    '# Anti-lockout S2',
    '',
    "| Test | Result |",
    "|------|--------|",
    "| S2.1 cold deny unprotected | $(if($r1.deny){'PASS'}else{'FAIL'}) |",
    "| S2.2 RECOVERY_UNLOCK | $(if($g.brain_tunnel_ok){'PASS'}else{'FAIL'}) |",
    "| S2.3 deny hooks sans tunnel | $(if($r3.deny){'PASS'}else{'FAIL'}) |"
) | Set-Content $report -Encoding UTF8
Pop-Location
if ($fail -gt 0) { exit 1 }
Write-Host "OK $report"
exit 0
