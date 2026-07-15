# Tests paliers hooks command fleet V11 — H1-H30 (+ H44 OpenLoop)
param(
    [switch]$SkipOpenLoop
)
$ErrorActionPreference = 'Stop'
$AgentPathEarly = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
function Restore-AgentGates {
    $g = Join-Path $AgentPathEarly '.cursor\agent-gates.json'
    $now = (Get-Date -Format o)
    $st = (Get-Date).AddMinutes(-10).ToString('o')
    $ts = @{vault_index_read=$now;user_profile_read=$now;erreurs_index_read=$now;biblio_index_read=$now;skills_index_read=$now;agent_note_read=$now;handoff_read=$now;agents_md_read=$now;spec_read=$now}
    @{brain_ok=$true;brain_tunnel_ok=$true;triage_ok=$true;session_started=$st;read_timestamps=$ts;vault_index_read=$true;user_profile_read=$true;erreurs_index_read=$true;biblio_index_read=$true;skills_index_read=$true;agent_note_read=$true;handoff_read=$true;agents_md_read=$true;spec_read=$true;mdc_read=$false}|ConvertTo-Json -Depth 6|Set-Content $g -Encoding UTF8
}
trap {
    if ((Get-Location).Path -ne $AgentPathEarly) { Pop-Location -ErrorAction SilentlyContinue }
    Restore-AgentGates
    throw $_
}
Remove-Item Env:ENFORCEMENT_MAINTENANCE -ErrorAction SilentlyContinue
$AgentPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Push-Location $AgentPath
$Hooks = Join-Path $AgentPath '.cursor\hooks'
$Gates = Join-Path $AgentPath '.cursor\agent-gates.json'
$Brain = Join-Path $AgentPath '.cursor\rules\00-brain-active.mdc'


function Invoke-Gate($script, $json) {
    $env:CURSOR_HOOK_TEST_INPUT = $json
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $script 2>&1
        $code = $LASTEXITCODE
    } catch {
        $out = $_.Exception.Message
        $code = 2
    }
    Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
    $ErrorActionPreference = $prev
    return @{ out = ($out | Out-String).Trim(); code = $code }
}

function Invoke-GateEmpty($script) {
    # Payload vide simule stdin Cursor ; eviter env="" (unset PS) et ReadToEnd bloquant
    $env:CURSOR_HOOK_TEST_INPUT = '{}'
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $script 2>&1
        $code = $LASTEXITCODE
    } catch {
        $out = $_.Exception.Message
        $code = 2
    }
    $ErrorActionPreference = $prev
    Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
    return @{ out = ($out | Out-String).Trim(); code = $code }
}

function Assert-Deny($r, $label, [string]$needle = '') {
    if ($r.code -ne 2 -or $r.out -notmatch '"permission":"deny"') {
        Write-Host "FAIL $label code=$($r.code) out=$($r.out)"
        exit 1
    }
    if ($needle -and $r.out -notmatch [regex]::Escape($needle)) {
        Write-Host "FAIL $label missing needle '$needle' out=$($r.out)"
        exit 1
    }
    Write-Host "PASS $label"
}

function Assert-Allow($r, $label) {
    if ($r.code -ne 0 -or $r.out -notmatch '"permission":"allow"') {
        Write-Host "FAIL $label code=$($r.code) out=$($r.out)"
        exit 1
    }
    Write-Host "PASS $label"
}


function New-ReadTimestamps([bool]$Spec=$true,[bool]$Mdc=$false){$n=(Get-Date -Format o);$ts=@{vault_index_read=$n;user_profile_read=$n;erreurs_index_read=$n;biblio_index_read=$n;skills_index_read=$n;agent_note_read=$n;handoff_read=$n;agents_md_read=$n};if($Spec){$ts.spec_read=$n};if($Mdc){$ts.mdc_read=$n};return $ts}
function Set-PartialTunnelGates([bool]$Spec = $false, [bool]$Mdc = $false) {
    # V21 : le tunnel ORDINAIRE = requiredReads complets (spec/mdc reserve au protege).
    # Reset-SessionReads d'abord (sinon merge avec un etat complet precedent -> tunnel=true a tort)
    # puis on laisse volontairement des requiredReads MANQUANTS (vault_index/erreurs/agent_note/handoff)
    # pour que brain_tunnel_ok reste false et que la gate DENY.
    . (Join-Path $Hooks '_hook-io.ps1')
    Reset-SessionReads $AgentPath
    Write-Gates $AgentPath @{
        brain_ok = $true
        agents_md_read = $true
        skills_index_read = $true
        spec_read = $Spec
        mdc_read = $Mdc
    }
}

function Set-FullReadProof {
    . (Join-Path $Hooks '_hook-io.ps1')
    Reset-ReadProof $AgentPath
    $vault = 'C:\Users\henri\OneDrive\Obsidian\AgentMemory\00_INDEX.md'
    $flags = Get-ReadFlagsForPath $vault
    Append-ReadProof $AgentPath $vault $flags
    foreach ($p in @(
        'C:\Users\henri\OneDrive\Obsidian\AgentMemory\users\henri-dusonchet.md',
        'C:\Users\henri\OneDrive\Obsidian\AgentMemory\erreurs\INDEX.md',
        'C:\Users\henri\OneDrive\Obsidian\AgentMemory\domains\bibliotheque\INDEX.md',
        'C:\Users\henri\OneDrive\Obsidian\AgentMemory\domains\cursor-skills\INDEX.md',
        'C:\Users\henri\OneDrive\Obsidian\AgentMemory\agents\003-expert-code.md',
        'C:\Users\henri\OneDrive\Obsidian\AgentMemory\sessions\_HANDOFF.md',
        (Join-Path $AgentPath 'AGENTS.md')
    )) {
        $f = Get-ReadFlagsForPath $p
        if ($f.Count -gt 0) { Append-ReadProof $AgentPath $p $f }
    }
    $spec = Get-ChildItem (Join-Path $AgentPath 'specs') -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($spec) {
        $f = Get-ReadFlagsForPath $spec.FullName
        if ($f.Count -gt 0) { Append-ReadProof $AgentPath $spec.FullName $f }
    }
}

function Set-FullTunnelGates([bool]$Spec = $true, [bool]$Mdc = $false) {
    @{
        brain_ok = $true
        session_started = (Get-Date).AddMinutes(-5).ToString('o')
        read_timestamps = (New-ReadTimestamps -Spec $Spec -Mdc $Mdc)
        vault_index_read = $true
        user_profile_read = $true
        erreurs_index_read = $true
        biblio_index_read = $true
        skills_index_read = $true
        agent_note_read = $true
        handoff_read = $true
        agents_md_read = $true
        spec_read = $Spec
        mdc_read = $Mdc
        triage_ok = ($Spec -or $Mdc)
    } | ConvertTo-Json -Depth 5 | Set-Content $Gates -Encoding UTF8
}

function Clear-ExternalGovernanceUnlock {
    . (Join-Path $Hooks '_hook-io.ps1')
    $path = Get-ExternalUnlockPath $AgentPath
    if (Test-Path $path) { Remove-Item $path -Force -ErrorAction SilentlyContinue }
}

Write-Host '=== Palier H1: fichiers hooks command V11 ==='
@(
    'gate-write-unified.ps1',
    'gate-write-triage.ps1',
    'gate-delete-triage.ps1',
    'gate-task-triage.ps1',
    'gate-shell-triage.ps1',
    'track-triage-read.ps1',
    '_hook-io.ps1'
) | ForEach-Object {
    if (-not (Test-Path (Join-Path $Hooks $_))) {
        Write-Host "FAIL missing $_"
        exit 1
    }
}

Write-Host '=== Palier H2: deny Write sans brain-active ==='
Remove-Item "$Brain.bak" -Force -ErrorAction SilentlyContinue
if (Test-Path $Brain) { Rename-Item $Brain "$Brain.bak" -Force }
if (Test-Path $Gates) { Remove-Item $Gates -Force }
$j = @{ tool_name = 'Write'; tool_input = @{ path = 'foo.txt' }; cwd = $AgentPath } | ConvertTo-Json -Compress
$r = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j
Assert-Deny $r 'H2'
if (-not (Test-Path $Brain)) { if (Test-Path "$Brain.bak") { Copy-Item "$Brain.bak" $Brain -Force } else { '{"alwaysApply":true}' | Set-Content $Brain -Encoding UTF8 } }

Write-Host '=== Palier H3: deny Write brain ok mais tunnel incomplet ==='
if (-not (Test-Path $Brain)) { '{"alwaysApply":true}' | Set-Content $Brain -Encoding UTF8 }
Set-PartialTunnelGates -Spec $false -Mdc $false
$r = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j
Assert-Deny $r 'H3'

Write-Host '=== Palier H4: allow Write apres tunnel complet ==='
Set-FullTunnelGates -Spec $true -Mdc $false
$r = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j
Assert-Allow $r 'H4'

Write-Host '=== Palier H5: deny typo StrReplace sans tunnel (fichier non protege) ==='
Remove-Item $Gates -Force -ErrorAction SilentlyContinue
if (-not (Test-Path $Brain)) { '{"alwaysApply":true}' | Set-Content $Brain -Encoding UTF8 }
$j = @{
    tool_name = 'StrReplace'
    tool_input = @{ path = 'foo.txt'; old_string = 'typo'; new_string = 'typo fixed' }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j
Assert-Deny $r 'H5' 'Tunnel cerveau incomplet'

Write-Host '=== Palier H6: stdin pipe sans crash ==='
Set-FullTunnelGates -Spec $true -Mdc $false
if (-not (Test-Path $Brain)) { '{"alwaysApply":true}' | Set-Content $Brain -Encoding UTF8 }
$jTask = @{ tool_name = 'Task'; cwd = $AgentPath } | ConvertTo-Json -Compress
$prevEa = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $pipeOut = $jTask | & (Join-Path $Hooks 'gate-task-triage.ps1') 2>&1
    $pipeCode = $LASTEXITCODE
} catch {
    $pipeOut = $_.Exception.Message
    $pipeCode = 1
}
$ErrorActionPreference = $prevEa
$pipeText = ($pipeOut | Out-String).Trim()
if ($pipeCode -eq 1 -or $pipeText -notmatch '"permission":"(allow|deny)"') {
    Write-Host "FAIL H6 code=$pipeCode out=$pipeText"
    exit 1
}
Write-Host 'PASS H6'

Write-Host '=== Palier H7: deny Shell Set-Content sans tunnel ==='
Set-PartialTunnelGates -Spec $false -Mdc $false
$jShell = @{
    tool_name = 'Shell'
    tool_input = @{ command = "Set-Content -Path foo.txt -Value bar" }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r = Invoke-Gate (Join-Path $Hooks 'gate-shell-triage.ps1') $jShell
Assert-Deny $r 'H7'

Write-Host '=== Palier H8: allow Shell verify-smoke sans triage ==='
Remove-Item $Gates -Force -ErrorAction SilentlyContinue
$jVerify = @{
    tool_name = 'Shell'
    tool_input = @{ command = "powershell -File tests\agent-smoke\verify-smoke-v03.ps1" }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r = Invoke-Gate (Join-Path $Hooks 'gate-shell-triage.ps1') $jVerify
Assert-Allow $r 'H8'

Write-Host '=== Palier H9: sessionStart nait sain (V21: tunnel=true + reads estampilles, spec non lu) ==='
# V21 juste milieu : la session doit naitre tunnel=true (fin de la "serrure sans cle").
# brain-load lit reellement les requiredReads (digest) -> flags estampilles (PAS fake).
# En revanche spec_read reste false (aucune spec domaine lue au demarrage) et trust_brain absent.
Remove-Item $Gates -Force -ErrorAction SilentlyContinue
if (-not (Test-Path $Brain)) { '{"alwaysApply":true}' | Set-Content $Brain -Encoding UTF8 }
$env:CURSOR_HOOK_TEST_INPUT = '{}'
$prevEa = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
Push-Location $AgentPath
try {
    & (Join-Path $Hooks 'session-start.ps1') | Out-Null
} finally {
    Pop-Location
    Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
    $ErrorActionPreference = $prevEa
}
if (-not (Test-Path $Gates)) {
    Write-Host 'FAIL H9 agent-gates.json missing'
    exit 1
}
$g9 = Get-Content $Gates -Raw | ConvertFrom-Json
if ($g9.brain_ok -ne $true -or $g9.brain_tunnel_ok -ne $true) {
    Write-Host "FAIL H9 brain_ok=$($g9.brain_ok) brain_tunnel_ok=$($g9.brain_tunnel_ok) (session doit naitre saine)"
    exit 1
}
if ($g9.spec_read -eq $true) {
    Write-Host "FAIL H9 spec_read=$($g9.spec_read) (aucune spec domaine lue au demarrage)"
    exit 1
}
# brain_tunnel_ok=true implique deja tous les flags tunnel estampilles fresh (config-agnostique)
if ($g9.trust_brain -eq $true) {
    Write-Host 'FAIL H9 trust_brain still set'
    exit 1
}
Write-Host 'PASS H9'

Write-Host '=== Palier H10: allow Write apres tunnel complet (agents+skills+spec) ==='
Remove-Item $Gates -Force -ErrorAction SilentlyContinue
if (-not (Test-Path $Brain)) { '{"alwaysApply":true}' | Set-Content $Brain -Encoding UTF8 }
$specPath = $null; $found = Get-ChildItem (Join-Path $AgentPath 'specs') -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue | Select-Object -First 1; if ($found) { $specPath = $found.FullName }
$agentsPath = Join-Path $AgentPath 'AGENTS.md'
$skillsPath = 'C:\Users\henri\OneDrive\Obsidian\AgentMemory\domains\cursor-skills\INDEX.md'
if ([string]::IsNullOrWhiteSpace($specPath) -or -not (Test-Path $specPath)) {
    Write-Host 'SKIP H10 spec.md absent dans specs/'
} elseif (-not (Test-Path $agentsPath)) {
    Write-Host "SKIP H10 AGENTS.md missing"
} elseif (-not (Test-Path $skillsPath)) {
    Write-Host "SKIP H10 skills INDEX missing: $skillsPath"
} else {
    foreach ($readPath in @($agentsPath, $skillsPath, $specPath)) {
        $jRead = @{ file_path = $readPath; cwd = $AgentPath } | ConvertTo-Json -Compress
        $env:CURSOR_HOOK_TEST_INPUT = $jRead
        & (Join-Path $Hooks 'track-triage-read.ps1') | Out-Null
        Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
    }
    Set-FullTunnelGates -Spec $true -Mdc $false
    $jWrite = @{ tool_name = 'Write'; tool_input = @{ path = 'foo.txt' }; cwd = $AgentPath } | ConvertTo-Json -Compress
    $r = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $jWrite
    Assert-Allow $r 'H10'
}

Write-Host '=== Palier H11: stdin vide fail-open (tunnel non evalue) ==='
if (-not (Test-Path $Brain)) { '{"alwaysApply":true}' | Set-Content $Brain -Encoding UTF8 }
Set-PartialTunnelGates -Spec $false -Mdc $false
$r11 = Invoke-GateEmpty (Join-Path $Hooks 'gate-write-unified.ps1')
Assert-Allow $r11 'H11'

Write-Host '=== Palier H12: stdin vide fail-open meme tunnel complet ==='
Set-FullTunnelGates -Spec $true -Mdc $false
$r12 = Invoke-GateEmpty (Join-Path $Hooks 'gate-write-unified.ps1')
Assert-Allow $r12 'H12'

Write-Host '=== Palier H13: stdin vide jamais Hook sans entree ==='
$allOut = $r11.out + $r12.out
if ($allOut -match 'Hook sans entree') {
    Write-Host 'FAIL H13 encore Hook sans entree sur stdin vide'
    exit 1
}
Write-Host 'PASS H13'

Write-Host '=== Palier H14: track-triage-read toujours JSON allow (failClosed) ==='
$env:CURSOR_HOOK_TEST_INPUT = '{}'
$prevEa = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $r14empty = & (Join-Path $Hooks 'track-triage-read.ps1') 2>&1
    $c14e = $LASTEXITCODE
} catch {
    $r14empty = $_.Exception.Message
    $c14e = 1
}
$t14e = ($r14empty | Out-String).Trim()
if ($c14e -ne 0 -or $t14e -notmatch '"permission":"allow"') {
    Write-Host "FAIL H14 stdin vide code=$c14e out=$t14e"
    exit 1
}
Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
$specPath = $null; $found = Get-ChildItem (Join-Path $AgentPath 'specs') -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue | Select-Object -First 1; if ($found) { $specPath = $found.FullName }
if (-not [string]::IsNullOrWhiteSpace($specPath) -and (Test-Path $specPath)) {
    $jRead = @{ file_path = $specPath; cwd = $AgentPath } | ConvertTo-Json -Compress
    $env:CURSOR_HOOK_TEST_INPUT = $jRead
    try {
        $r14spec = & (Join-Path $Hooks 'track-triage-read.ps1') 2>&1
        $c14s = $LASTEXITCODE
    } catch {
        $r14spec = $_.Exception.Message
        $c14s = 1
    }
    Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
    $t14s = ($r14spec | Out-String).Trim()
    if ($c14s -ne 0 -or $t14s -notmatch '"permission":"allow"') {
        Write-Host "FAIL H14 spec read code=$c14s out=$t14s"
        exit 1
    }
}
$ErrorActionPreference = $prevEa
Write-Host 'PASS H14'

if (Test-Path "$Brain.bak") {
    Remove-Item $Brain -Force -ErrorAction SilentlyContinue
    Rename-Item "$Brain.bak" $Brain -Force
}
Set-FullTunnelGates -Spec $true -Mdc $false

Write-Host '=== H15 unified cible vide ==='
Set-FullTunnelGates -Spec $true
$jE=@{tool_name='Write';tool_input=@{};cwd=$AgentPath}|ConvertTo-Json -Compress
Assert-Deny (Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $jE) 'H15' 'Cible Write absente'
Write-Host '=== H16 Delete sans tunnel ==='
Set-PartialTunnelGates -Spec $false
$jD=@{tool_name='Delete';tool_input=@{path='x.txt'};cwd=$AgentPath}|ConvertTo-Json -Compress
Assert-Deny (Invoke-Gate (Join-Path $Hooks 'gate-delete-triage.ps1') $jD) 'H16' 'Tunnel cerveau incomplet'
Write-Host '=== H17 alias triage==unified ==='
Set-FullTunnelGates -Spec $true
$jW=@{tool_name='Write';tool_input=@{path='foo.txt'};cwd=$AgentPath}|ConvertTo-Json -Compress
$a=Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $jW; $b=Invoke-Gate (Join-Path $Hooks 'gate-write-triage.ps1') $jW
if($a.code -ne $b.code){exit 1}; Write-Host 'PASS H17'
Write-Host '=== Palier H18: hooks.json reference unified ==='
$hj = Get-Content (Join-Path $AgentPath '.cursor\hooks.json') -Raw | ConvertFrom-Json
$writeHook = $hj.hooks.preToolUse | Where-Object { $_.matcher -match 'Write' } | Select-Object -First 1
if (-not $writeHook -or $writeHook.command -notmatch 'unified') {
    Write-Host "FAIL H18 command=$($writeHook.command)"
    exit 1
}
Write-Host 'PASS H18'

Write-Host '=== Palier H19: deny Write spec sans reflection-proof ==='
Clear-ExternalGovernanceUnlock
Set-FullTunnelGates -Spec $true -Mdc $false
$reflDir = Join-Path $AgentPath '.cursor\research'
if (Test-Path $reflDir) { Remove-Item (Join-Path $reflDir 'reflection-proof.json') -Force -ErrorAction SilentlyContinue }
$specRel = $null
$found = Get-ChildItem (Join-Path $AgentPath 'specs') -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($found) { $specRel = $found.FullName }
if (-not $specRel) {
    Write-Host 'SKIP H19 spec.md introuvable'
} else {
    $jSpec = @{ tool_name = 'Write'; tool_input = @{ path = $specRel }; cwd = $AgentPath } | ConvertTo-Json -Compress
    $r19 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $jSpec
    Assert-Deny $r19 'H19' 'Unlock gouvernance requis'
}

Write-Host '=== Palier H20: allow Write spec apres record-reflection-proof ==='
if ($specRel) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $AgentPath 'scripts\ISSUE_GOVERNANCE_UNLOCK.ps1') -Scope @($specRel) | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $AgentPath 'scripts\record-reflection-proof.ps1') -Competence competence_deja_disponible -TaskType audit | Out-Null
    $jSpec2 = @{ tool_name = 'Write'; tool_input = @{ path = $specRel }; cwd = $AgentPath } | ConvertTo-Json -Compress
    $r20 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $jSpec2
    Assert-Allow $r20 'H20'
}

Write-Host '=== Palier H21: deny Shell install-skills sans tunnel ==='
Set-PartialTunnelGates -Spec $false -Mdc $false
$jSkills = @{
    tool_name = 'Shell'
    tool_input = @{ command = "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-skills-sh.ps1" }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r21 = Invoke-Gate (Join-Path $Hooks 'gate-shell-triage.ps1') $jSkills
Assert-Deny $r21 'H21' 'Tunnel cerveau incomplet'

Write-Host '=== Palier H26: deny StrReplace spec sans gates (L21) ==='
Remove-Item $Gates -Force -ErrorAction SilentlyContinue
$reflDir26 = Join-Path $AgentPath '.cursor\research'
if (Test-Path $reflDir26) { Remove-Item (Join-Path $reflDir26 'reflection-proof.json') -Force -ErrorAction SilentlyContinue }
$specFor26 = $null
$found26 = Get-ChildItem (Join-Path $AgentPath 'specs') -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($found26) { $specFor26 = $found26.FullName }
if (-not $specFor26) {
    Write-Host 'SKIP H26 spec.md absent'
} else {
    $j26 = @{
        tool_name = 'StrReplace'
        tool_input = @{ path = $specFor26; old_string = 'Status'; new_string = 'Status' }
        cwd = $AgentPath
    } | ConvertTo-Json -Compress
    $r26 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j26
    Assert-Deny $r26 'H26' 'incomplet'
}

Write-Host '=== Palier H27: deny StrReplace spec tunnel partiel ==='
if ($specFor26) {
    if (Test-Path $reflDir26) { Remove-Item (Join-Path $reflDir26 'reflection-proof.json') -Force -ErrorAction SilentlyContinue }
    Set-PartialTunnelGates -Spec $true -Mdc $false
    $j27 = @{
        tool_name = 'StrReplace'
        tool_input = @{ path = $specFor26; old_string = 'Status'; new_string = 'Status' }
        cwd = $AgentPath
    } | ConvertTo-Json -Compress
    $r27 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j27
    Assert-Deny $r27 'H27' 'incomplet'
}

Write-Host '=== Palier H28: allow StrReplace spec apres tunnel + reflection ==='
if ($specFor26) {
    Set-FullTunnelGates -Spec $true -Mdc $false
    $reflDir = Join-Path $AgentPath '.cursor\research'
    if (Test-Path $reflDir) { Remove-Item (Join-Path $reflDir 'reflection-proof.json') -Force -ErrorAction SilentlyContinue }
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $AgentPath 'scripts\ISSUE_GOVERNANCE_UNLOCK.ps1') -Scope @($specFor26) | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $AgentPath 'scripts\record-reflection-proof.ps1') -Competence competence_deja_disponible -TaskType audit | Out-Null
    $j28 = @{
        tool_name = 'StrReplace'
        tool_input = @{ path = $specFor26; old_string = 'Status'; new_string = 'Status' }
        cwd = $AgentPath
    } | ConvertTo-Json -Compress
    $r28 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j28
    Assert-Allow $r28 'H28'
}

Write-Host '=== Palier H29: deny Write hors workspace (L23) ==='
Set-FullTunnelGates -Spec $true -Mdc $false
$fleetRoot = Split-Path $AgentPath -Parent
$peerAgents = @('018_Trader', '010_Padel', '003_Agent V01 - Expert en code - V01', '17_Agent pi')
$outside = $null
foreach ($peer in $peerAgents) {
    $peerRoot = Join-Path $fleetRoot $peer
    if (-not (Test-Path $peerRoot)) { continue }
    if (([System.IO.Path]::GetFullPath($peerRoot)).TrimEnd('\').Equals(([System.IO.Path]::GetFullPath($AgentPath)).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { continue }
    $foundOutside = Get-ChildItem $peerRoot -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundOutside) { $outside = $foundOutside.FullName; break }
}
if ($outside) {
    $j29 = @{
        tool_name = 'StrReplace'
        tool_input = @{ path = $outside; old_string = 'x'; new_string = 'x' }
        cwd = $AgentPath
    } | ConvertTo-Json -Compress
    $r29 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j29
    Assert-Deny $r29 'H29' 'hors workspace'
} else {
    Write-Host 'SKIP H29 aucun spec.md hors workspace'
}

Write-Host '=== Palier H30: deny StrReplace spec proof calibration perime (L27) ==='
if ($specFor26) {
    $reflDir30 = Join-Path $AgentPath '.cursor\research'
    if (-not (Test-Path $reflDir30)) { New-Item -ItemType Directory -Path $reflDir30 -Force | Out-Null }
    Set-FullTunnelGates -Spec $true -Mdc $false
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $AgentPath 'scripts\ISSUE_GOVERNANCE_UNLOCK.ps1') -Scope @($specFor26) | Out-Null
    @{
        updated_at = '2026-07-01T10:00:00'
        task_type = 'audit'
        tunnel = @{ competence = 'competence_deja_disponible'; spec = $true; mdc = $false; brain = $true; skills = $true }
        external = @{ required = $false; web = $false; github = $false }
    } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $reflDir30 'reflection-proof.json') -Encoding UTF8
    $j30 = @{
        tool_name = 'StrReplace'
        tool_input = @{ path = $specFor26; old_string = 'Status'; new_string = 'Status' }
        cwd = $AgentPath
    } | ConvertTo-Json -Compress
    $r30 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j30
    Assert-Deny $r30 'H30' 'perime'
}

Write-Host '=== Palier H31: deny Shell record-brain-reads sans unlock ==='
Set-PartialTunnelGates -Spec $false -Mdc $false
$j31 = @{
    tool_name = 'Shell'
    tool_input = @{ command = '.\scripts\record-brain-reads.ps1 -MarkSpec' }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r31 = Invoke-Gate (Join-Path $Hooks 'gate-shell-triage.ps1') $j31
Assert-Deny $r31 'H31' 'Tunnel cerveau incomplet'

Write-Host '=== Palier H32: deny Shell reflection sans unlock ==='
Set-PartialTunnelGates -Spec $false -Mdc $false
$j32 = @{
    tool_name = 'Shell'
    tool_input = @{ command = 'powershell -NoProfile -File .\scripts\record-reflection-proof.ps1 -Competence competence_deja_disponible -TaskType audit' }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r32 = Invoke-Gate (Join-Path $Hooks 'gate-shell-triage.ps1') $j32
Assert-Deny $r32 'H32' 'Tunnel cerveau incomplet'

Write-Host '=== Palier H33: beforeShellExecution format deny Set-Content ==='
Set-PartialTunnelGates -Spec $false -Mdc $false
$j33 = @{ command = 'Set-Content foo.txt bar'; cwd = $AgentPath } | ConvertTo-Json -Compress
$r33 = Invoke-Gate (Join-Path $Hooks 'gate-shell-triage.ps1') $j33
Assert-Deny $r33 'H33' 'Tunnel cerveau incomplet'

Write-Host '=== Palier H34: deny Write agent-gates hors maintenance ==='
. (Join-Path $Hooks '_hook-io.ps1')
Reset-SessionReads $AgentPath
$j34 = @{
    tool_name = 'Write'
    tool_input = @{ path = '.cursor\agent-gates.json'; contents = '{}' }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r34 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j34
Assert-Deny $r34 'H34'

Write-Host '=== Palier H35: deny hooks edit sans unlock ==='
Reset-SessionReads $AgentPath
$hook35 = Join-Path $AgentPath '.cursor\hooks\gate-write-unified.ps1'
$j35 = @{
    tool_name = 'Write'
    tool_input = @{ path = $hook35; contents = '# x' }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r35 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j35
Assert-Deny $r35 'H35' 'Unlock gouvernance requis'

Write-Host '=== Palier H36: deny StrReplace spec sans tunnel (regression) ==='
Reset-SessionReads $AgentPath
$spec36 = Get-ChildItem (Join-Path $AgentPath 'specs') -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($spec36) {
    $j36 = @{
        tool_name = 'StrReplace'
        tool_input = @{ path = $spec36.FullName; old_string = 'Status'; new_string = 'Status' }
        cwd = $AgentPath
    } | ConvertTo-Json -Compress
    $r36 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j36
    Assert-Deny $r36 'H36' 'Tunnel cerveau incomplet'
} else { Write-Host 'SKIP H36 no spec.md' }

Write-Host '=== Palier H37: deny spec avec reflection seule sans tunnel ==='
Reset-SessionReads $AgentPath
$rd = Join-Path $AgentPath '.cursor\research'
if (-not (Test-Path $rd)) { New-Item -ItemType Directory -Path $rd -Force | Out-Null }
@{ updated_at = (Get-Date -Format o); tunnel = @{ competence = 'competence_deja_disponible'; spec = $true } } | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $rd 'reflection-proof.json') -Encoding UTF8
if ($spec36) {
    $j37 = @{
        tool_name = 'StrReplace'
        tool_input = @{ path = $spec36.FullName; old_string = 'Status'; new_string = 'Status' }
        cwd = $AgentPath
    } | ConvertTo-Json -Compress
    $r37 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j37
    Assert-Deny $r37 'H37' 'Tunnel cerveau incomplet'
} else { Write-Host 'SKIP H37 no spec.md' }

Write-Host '=== Palier H38: deny Write hors workspace (regression L23) ==='
Set-FullTunnelGates -Spec $true -Mdc $false
$fleetRoot = Split-Path $AgentPath -Parent
$outside38 = $null
foreach ($peer in @('018_Trader', '010_Padel', '003_Agent V01 - Expert en code - V01', '17_Agent pi')) {
    $peerRoot = Join-Path $fleetRoot $peer
    if (-not (Test-Path $peerRoot)) { continue }
    if (([System.IO.Path]::GetFullPath($peerRoot)).TrimEnd('\').Equals(([System.IO.Path]::GetFullPath($AgentPath)).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { continue }
    $found38 = Get-ChildItem $peerRoot -Recurse -Filter 'spec.md' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found38) { $outside38 = $found38; break }
}
if ($outside38) {
    $j38 = @{
        tool_name = 'StrReplace'
        tool_input = @{ path = $outside38.FullName; old_string = 'x'; new_string = 'x' }
        cwd = $AgentPath
    } | ConvertTo-Json -Compress
    $r38 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j38
    Assert-Deny $r38 'H38' 'hors workspace'
} else { Write-Host 'SKIP H38' }

Write-Host '=== Palier H39: RECOVERY_UNLOCK restaure gates + unlock hors hooks ==='
Reset-SessionReads $AgentPath
& powershell -NoProfile -EP Bypass -File (Join-Path $AgentPath 'scripts\RECOVERY_UNLOCK_AGENT.ps1') | Out-Null
$g39 = Get-Content $Gates -Raw | ConvertFrom-Json
if ($g39.brain_tunnel_ok -ne $true) { Write-Host 'FAIL H39 brain_tunnel_ok'; exit 1 }
. (Join-Path $Hooks '_hook-io.ps1')
if (-not (Test-GovernanceUnlock $AgentPath (Join-Path $AgentPath 'docs\TERRAIN_TEST_PROTOCOL.md'))) { Write-Host 'FAIL H39 unlock absent'; exit 1 }
Write-Host 'PASS H39'

Write-Host '=== Palier H40: research writable mais non autoritaire ==='
Reset-SessionReads $AgentPath
$research40 = Join-Path $AgentPath '.cursor\research\v14-observe.json'
$j40 = @{
    tool_name = 'Write'
    tool_input = @{ path = $research40; contents = '{"obs":true}' }
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r40 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $j40
$r40s = & { $env:CURSOR_HOOK_TEST_INPUT = $j40; & (Join-Path $Hooks 'sync-gates-after-write.ps1') | Out-Null; Remove-Item Env:CURSOR_HOOK_TEST_INPUT -EA SilentlyContinue }
$g40 = Get-Content $Gates -Raw | ConvertFrom-Json
if ($r40.code -ne 0 -or $g40.brain_tunnel_ok -eq $true) { Write-Host 'FAIL H40 observability write changed authority'; exit 1 }
Write-Host 'PASS H40'

Write-Host '=== Palier H41: Select-HookJsonPayload garde JSON imbrique dans contents ==='
. (Join-Path $Hooks '_hook-io.ps1')
$nested41 = @{
    tool_name = 'Write'
    tool_input = @{
        path = (Join-Path $AgentPath '.cursor\research\reflection-proof.json')
        contents = "{`n  `"updated_at`": `"now`",`n  `"tunnel`": { `"competence`": `"competence_deja_disponible`" }`n}"
    }
    cwd = $AgentPath
} | ConvertTo-Json -Depth 6 -Compress
$extracted41 = Select-HookJsonPayload ("noise avant json`n" + $nested41)
if ([string]::IsNullOrWhiteSpace($extracted41)) { Write-Host 'FAIL H41 extraction vide'; exit 1 }
try { $null = $extracted41 | ConvertFrom-Json } catch { Write-Host 'FAIL H41 extraction illisible'; exit 1 }
Reset-SessionReads $AgentPath
$r41 = Invoke-Gate (Join-Path $Hooks 'gate-write-unified.ps1') $nested41
if ($r41.code -ne 0) { Write-Host "FAIL H41 allow research nested contents code=$($r41.code) out=$($r41.out)"; exit 1 }
Write-Host 'PASS H41'

Write-Host '=== Palier H42: track-librarian-pretool sur CallMcpTool ==='
. (Join-Path $Hooks '_hook-io.ps1')
Write-Gates $AgentPath @{ librarian_used = $false; librarian_calls = 0 }
$j42 = @{
    tool_name = 'CallMcpTool'
    tool_input = @{
        server = 'user-librarian'
        toolName = 'library_traverse'
        arguments = @{ start = 'MAP-padel'; depth = 1 }
    }
    cwd = $AgentPath
} | ConvertTo-Json -Depth 6 -Compress
$r42 = Invoke-Gate (Join-Path $Hooks 'track-librarian-pretool.ps1') $j42
$g42 = Get-Content $Gates -Raw | ConvertFrom-Json
if ($r42.code -ne 0) { Write-Host "FAIL H42 exit code=$($r42.code)"; exit 1 }
if ($g42.librarian_used -ne $true -or [int]$g42.librarian_calls -lt 1) {
    Write-Host "FAIL H42 gates librarian_used=$($g42.librarian_used) calls=$($g42.librarian_calls)"
    exit 1
}
Write-Host 'PASS H42'

Write-Host '=== Palier H43: track-librarian-mcp beforeMCPExecution ==='
$j43 = @{
    mcp_server = 'user-librarian'
    tool_name = 'library_read'
    cwd = $AgentPath
} | ConvertTo-Json -Compress
$r43 = Invoke-Gate (Join-Path $Hooks 'track-librarian-mcp.ps1') $j43
$g43 = Get-Content $Gates -Raw | ConvertFrom-Json
if ($r43.code -ne 0) { Write-Host "FAIL H43 exit code=$($r43.code)"; exit 1 }
if ([int]$g43.librarian_calls -lt 2) {
    Write-Host "FAIL H43 librarian_calls=$($g43.librarian_calls) attendu >= 2"
    exit 1
}
Write-Host 'PASS H43'

$olTerrain = Join-Path $AgentPath 'tests\hooks\RUN_TERRAIN_OPENLOOP_003.ps1'
if (-not $SkipOpenLoop -and (Test-Path $olTerrain)) {
    Write-Host '=== Palier H44: OpenLoop terrain OL1-OL8 (nested skip full hooks) ==='
    $env:OPENLOOP_NESTED = '1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $olTerrain -SkipHookTests
    $olCode = $LASTEXITCODE
    Remove-Item Env:OPENLOOP_NESTED -ErrorAction SilentlyContinue
    if ($olCode -ne 0) {
        Write-Host "FAIL H44 OpenLoop terrain exit=$olCode"
        exit 1
    }
    Write-Host 'PASS H44'
} elseif ($SkipOpenLoop) {
    Write-Host 'SKIP H44 OpenLoop (-SkipOpenLoop)'
} else {
    Write-Host 'SKIP H44 OpenLoop (pilot 003 uniquement, RUN_TERRAIN_OPENLOOP_003.ps1 absent sur cet agent)'
}

Write-Host 'HOOK TESTS PASS (43+ paliers fleet V18)'
Restore-AgentGates






