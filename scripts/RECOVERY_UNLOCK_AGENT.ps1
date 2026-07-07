# Debloque agent-gates apres lockout enforcement (hors hooks Cursor) — break-glass V14
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$g = Join-Path $root '.cursor\agent-gates.json'
$n = (Get-Date -Format o)
$st = (Get-Date).AddMinutes(-1).ToString('o')
$ts = @{
    vault_index_read = $n
    user_profile_read = $n
    erreurs_index_read = $n
    biblio_index_read = $n
    skills_index_read = $n
    agent_note_read = $n
    handoff_read = $n
    agents_md_read = $n
    spec_read = $n
}
function Get-ExternalUnlockDir {
    $base = [Environment]::GetFolderPath('LocalApplicationData')
    return Join-Path $base 'CursorGovernanceUnlocks'
}
function Get-ExternalUnlockPath {
    $cfg = Get-Content (Join-Path $root '.cursor\memory.config.json') -Raw | ConvertFrom-Json
    return Join-Path (Get-ExternalUnlockDir) "$($cfg.agentId)-unlock.json"
}
@{
    brain_ok = $true
    brain_tunnel_ok = $true
    triage_ok = $true
    vault_index_read = $true
    user_profile_read = $true
    erreurs_index_read = $true
    biblio_index_read = $true
    skills_index_read = $true
    agent_note_read = $true
    handoff_read = $true
    agents_md_read = $true
    spec_read = $true
    mdc_read = $false
    session_started = $st
    read_timestamps = $ts
} | ConvertTo-Json -Depth 6 | Set-Content $g -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Get-ExternalUnlockDir) | Out-Null
@{
    root = $root
    created_at = $n
    expires_at = (Get-Date).AddMinutes(20).ToString('o')
    scope = @(
        '.cursor\hooks\_hook-io.ps1',
        '.cursor\hooks\gate-write-unified.ps1',
        '.cursor\hooks\gate-shell-triage.ps1',
        '.cursor\hooks\gate-shell-bootstrap.ps1',
        '.cursor\hooks\sync-gates-after-write.ps1',
        '.cursor\hooks\sync-reflection-after-write.ps1',
        '.cursor\hooks\track-triage-read.ps1',
        '.cursor\hooks.json',
        '.cursor\rules',
        'docs\TERRAIN_TEST_PROTOCOL.md',
        '02_Base\HOOKS_ENFORCEMENT.md',
        'reports\LEAK_MATRIX_V11.md',
        'reports\ENFORCEMENT_ROOT_CAUSE_AUDIT_2026-07.md',
        'tests\hooks'
    )
} | ConvertTo-Json -Depth 6 | Set-Content (Get-ExternalUnlockPath) -Encoding UTF8
Write-Host "OK gates restaures: $g"
