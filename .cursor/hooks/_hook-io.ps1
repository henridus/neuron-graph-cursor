function Out-Deny([string]$UserMsg, [string]$AgentMsg) {
    $o = @{ permission = 'deny'; user_message = $UserMsg; agent_message = $AgentMsg }
    $o | ConvertTo-Json -Compress | Write-Output
    exit 2
}
function Out-Allow { '{"permission":"allow"}' | Write-Output; exit 0 }
function Select-HookJsonPayload([string]$Raw) {
    if ([string]::IsNullOrWhiteSpace($Raw)) { return '' }
    $raw = $Raw.Trim()
    $start = $raw.IndexOf('{')
    if ($start -lt 0) { return '' }
    $candidate = $raw.Substring($start)
    try {
        $null = $candidate | ConvertFrom-Json
        return $candidate
    } catch { }
    return ''
}
function Read-HookInput {
    if ($null -ne $env:CURSOR_HOOK_TEST_INPUT) { return $env:CURSOR_HOOK_TEST_INPUT }
    $raw = ''
    try {
        foreach ($scope in 1..4) {
            try {
                $var = Get-Variable -Scope $scope -Name input -ErrorAction SilentlyContinue
                if ($var -and $null -ne $var.Value) {
                    $parts = @($var.Value | ForEach-Object { [string]$_ })
                    if ($parts.Count -gt 0) { $raw = ($parts -join "`n").Trim(); break }
                }
            } catch { }
        }
        if ([string]::IsNullOrWhiteSpace($raw) -and $null -ne $args -and $args.Count -gt 0) {
            $raw = ($args -join ' ').Trim()
        }
        if ([string]::IsNullOrWhiteSpace($raw) -and [Console]::IsInputRedirected) {
            try {
                $t = [System.Threading.Tasks.Task[string]]::Run([Func[string]]{ [Console]::In.ReadToEnd() })
                if ($t.Wait(800)) { $raw = $t.Result }
            } catch { }
        }
    } catch { }
    return (Select-HookJsonPayload $raw)
}
function Get-ProjectRoot([string]$Cwd) {
    if ([string]::IsNullOrWhiteSpace($Cwd)) { $Cwd = (Get-Location).Path }
    $p = $Cwd
    for ($i = 0; $i -lt 8; $i++) {
        if (Test-Path (Join-Path $p '.cursor\hooks.json')) { return $p }
        $parent = Split-Path $p -Parent
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $p) { break }
        $p = $parent
    }
    return $Cwd
}
function Get-GatesPath([string]$Root) { return Join-Path $Root '.cursor\agent-gates.json' }
function Get-MemoryConfig([string]$Root) {
    $path = Join-Path $Root '.cursor\memory.config.json'
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
}
function Get-FlagNameForRequiredRead([string]$Rel) {
    $r = ($Rel -replace '\\', '/').Trim().ToLower()
    if ($r -eq '00_index.md') { return 'vault_index_read' }
    if ($r -match 'users/henri-dusonchet') { return 'user_profile_read' }
    if ($r -match 'erreurs/index') { return 'erreurs_index_read' }
    if ($r -match 'bibliotheque/index') { return 'biblio_index_read' }
    if ($r -match 'cursor-skills/index') { return 'skills_index_read' }
    if ($r -match '^agents/') { return 'agent_note_read' }
    if ($r -match 'agents\.md$') { return 'agents_md_read' }
    if ($r -match '_handoff') { return 'handoff_read' }
    return ('req_' + ($r -replace '[^a-z0-9]+', '_'))
}
function Get-BrainTunnelFlagNames([string]$Root) {
    $names = [System.Collections.Generic.List[string]]::new()
    $cfg = Get-MemoryConfig $Root
    if ($cfg -and $cfg.requiredReads) {
        foreach ($rel in $cfg.requiredReads) {
            $f = Get-FlagNameForRequiredRead $rel
            if ($f -and -not $names.Contains($f)) { $names.Add($f) }
        }
    }
    foreach ($extra in @('handoff_read', 'agents_md_read')) {
        if (-not $names.Contains($extra)) { $names.Add($extra) }
    }
    return $names
}
function Read-Gates([string]$Root) {
    $path = Get-GatesPath $Root
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
}
function Write-Gates([string]$Root, [hashtable]$Data) {
    $path = Get-GatesPath $Root
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $out = @{}
    $existing = Read-Gates $Root
    if ($existing) { $existing.PSObject.Properties | ForEach-Object { $out[$_.Name] = $_.Value } }
    foreach ($k in $Data.Keys) {
        if ($k -eq 'brain_ok' -or $k -match '_read$' -or $k -eq 'competence_recorded') {
            if ($Data[$k] -eq $true) {
                $out[$k] = $true
                if ($k -match '_read$') {
                    if (-not $out['read_timestamps']) { $out['read_timestamps'] = @{} }
                    $ts = @{}
                    if ($out['read_timestamps'] -is [hashtable]) { $ts = $out['read_timestamps'] }
                    elseif ($out['read_timestamps']) { $out['read_timestamps'].PSObject.Properties | ForEach-Object { $ts[$_.Name] = $_.Value } }
                    $ts[$k] = (Get-Date -Format o)
                    $out['read_timestamps'] = $ts
                }
            }
            elseif ($Data[$k] -eq $false) {
                $out[$k] = $false
                if ($k -match '_read$' -and $out['read_timestamps']) {
                    $ts = @{}
                    if ($out['read_timestamps'] -is [hashtable]) {
                        foreach ($tk in $out['read_timestamps'].Keys) { $ts[$tk] = $out['read_timestamps'][$tk] }
                    } else {
                        $out['read_timestamps'].PSObject.Properties | ForEach-Object { $ts[$_.Name] = $_.Value }
                    }
                    if ($ts.ContainsKey($k)) { $ts.Remove($k) }
                    $out['read_timestamps'] = $ts
                }
            }
        } elseif ($k -eq 'read_timestamps') { $out['read_timestamps'] = $Data[$k] }
        else { $out[$k] = $Data[$k] }
    }
    if ($out['brain_ok'] -ne $true -and (Test-BrainActive $Root)) { $out['brain_ok'] = $true }
    $tunnelOk = Test-BrainTunnelOkFromGates $Root $out
    $out['brain_tunnel_ok'] = $tunnelOk
    $out['triage_ok'] = $tunnelOk
    $out['updated_at'] = (Get-Date -Format o)
    $out | ConvertTo-Json -Depth 4 | Set-Content $path -Encoding UTF8
}
function Test-BrainTunnelSessionFresh([string]$Root, $GateObj) {
    if (-not $GateObj) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$GateObj.session_started)) { return $false }
    try { $sessionAt = [datetime]::Parse([string]$GateObj.session_started) } catch { return $false }
    $tsObj = $GateObj.read_timestamps
    if (-not $tsObj) { return $false }
    $getAt = {
        param($name)
        if ($tsObj -is [hashtable]) { return $tsObj[$name] }
        return $tsObj.$name
    }
    foreach ($flag in (Get-BrainTunnelFlagNames $Root)) {
        $at = & $getAt $flag
        if ([string]::IsNullOrWhiteSpace([string]$at)) { return $false }
        try { if ([datetime]::Parse([string]$at) -lt $sessionAt) { return $false } } catch { return $false }
    }
    $domainFlag = if ($GateObj.spec_read -eq $true) { 'spec_read' } elseif ($GateObj.mdc_read -eq $true) { 'mdc_read' } else { return $false }
    $dat = & $getAt $domainFlag
    if ([string]::IsNullOrWhiteSpace([string]$dat)) { return $false }
    try { return ([datetime]::Parse([string]$dat) -ge $sessionAt) } catch { return $false }
}
function Test-BrainTunnelOkFromGates([string]$Root, $GateObj) {
    if (-not (Test-BrainActive $Root)) { return $false }
    foreach ($flag in (Get-BrainTunnelFlagNames $Root)) { if ($GateObj.$flag -ne $true) { return $false } }
    if (-not (($GateObj.spec_read -eq $true) -or ($GateObj.mdc_read -eq $true))) { return $false }
    return (Test-BrainTunnelSessionFresh $Root $GateObj)
}
function Test-BrainTunnelOk([string]$Root) { $g = Read-Gates $Root; if (-not $g) { return $false }; return Test-BrainTunnelOkFromGates $Root $g }
function Enforce-DiskTriageGate([string]$Root, [string]$ActionLabel) {
    if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { Out-Allow }
    if (-not (Test-BrainActive $Root)) { Out-Deny 'Brain non charge' ("sessionStart requis. Action: $ActionLabel") }
    if (-not (Test-BrainTunnelOk $Root)) { Out-Deny 'Tunnel cerveau incomplet' ("Lire requiredReads. Action: $ActionLabel") }
    Out-Allow
}
function Test-TriageOk([string]$Root) { Test-BrainTunnelOk $Root }
function Test-DomainTriageOk([string]$Root) { Test-BrainTunnelOk $Root }
function Test-BrainActive([string]$Root) { Test-Path (Join-Path $Root '.cursor\rules\00-brain-active.mdc') }
function Test-ReflectionRequiredPath([string]$NormPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    $p = ($NormPath -replace '/', '\').ToLower()
    return ($p -match '(^|[\\/])docs\\.*\.md$') -or ($p -match '(^|[\\/])specs\\[^\\]+\\spec\.md$') -or ($p -match '(^|[\\/])specs\\[^\\]+\\plan\.md$') -or ($p -match '(^|[\\/])agents\.md$')
}
function Test-SpecDomainPath([string]$NormPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    $p = $NormPath -replace '/', '\'
    return ($p -match '(^|\\)specs\\[^\\]+\\tasks\.md$') -or ($p -match '(\\|^)\.cursor\\rules\\(?!00-brain-active)[^\\]+\.mdc$')
}
function Get-ReflectionProofPath([string]$Root) { Join-Path $Root '.cursor\research\reflection-proof.json' }
function Read-ReflectionProof([string]$Root) {
    $path = Get-ReflectionProofPath $Root
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
}
function Init-ReflectionProof([string]$Root, [string]$Domaine, [bool]$Brain) {
    $dir = Join-Path $Root '.cursor\research'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    @{ date=(Get-Date -Format 'yyyy-MM-dd'); updated_at=(Get-Date -Format o); domaine=$Domaine; task_type='pending'; tunnel=@{brain=$Brain;skills=$false;spec=$false;mdc=$false;competence=''}; external=@{required=$false;web=$false;github=$false} } | ConvertTo-Json -Depth 6 | Set-Content (Get-ReflectionProofPath $Root) -Encoding UTF8
}
function Write-ReflectionProof([string]$Root, [hashtable]$Data) {
    $base = @{}
    $existing = Read-ReflectionProof $Root
    if ($existing) { $existing.PSObject.Properties | ForEach-Object { $base[$_.Name] = $_.Value } }
    foreach ($k in $Data.Keys) { $base[$k] = $Data[$k] }
    $base['updated_at'] = (Get-Date -Format o)
    $base | ConvertTo-Json -Depth 6 | Set-Content (Get-ReflectionProofPath $Root) -Encoding UTF8
}
function Update-ReflectionTunnel([string]$Root, [hashtable]$Flags) {
    if (-not (Read-ReflectionProof $Root)) { Init-ReflectionProof $Root 'general' $true }
    $path = Get-ReflectionProofPath $Root
    $obj = Get-Content $path -Raw | ConvertFrom-Json
    if (-not $obj.tunnel) { $obj | Add-Member -NotePropertyName tunnel -NotePropertyValue (@{}) }
    foreach ($k in $Flags.Keys) { $obj.tunnel.$k = $Flags[$k] }
    $obj.updated_at = (Get-Date -Format o)
    $obj | ConvertTo-Json -Depth 6 | Set-Content $path -Encoding UTF8
}
function Update-ReflectionExternal([string]$Root, [hashtable]$Flags) {
    if (-not (Read-ReflectionProof $Root)) { Init-ReflectionProof $Root 'general' $true }
    $path = Get-ReflectionProofPath $Root
    $obj = Get-Content $path -Raw | ConvertFrom-Json
    if (-not $obj.external) { $obj | Add-Member -NotePropertyName external -NotePropertyValue (@{}) }
    foreach ($k in $Flags.Keys) { $obj.external.$k = $Flags[$k] }
    $obj.updated_at = (Get-Date -Format o)
    $obj | ConvertTo-Json -Depth 6 | Set-Content $path -Encoding UTF8
}
function Test-GithubInventoryOk([string]$Root) {
    $path = Join-Path $Root '.cursor\research\github-inventory.json'
    if (-not (Test-Path $path)) { return $false }
    try {
        $inv = Get-Content $path -Raw | ConvertFrom-Json
        if (-not $inv.repos -or @($inv.repos).Count -lt 3) { return $false }
        if ($inv.date -and (((Get-Date) - [datetime]::Parse([string]$inv.date)).TotalDays -gt 14)) { return $false }
        return $true
    } catch { return $false }
}
function Test-ReflectionSessionFresh([string]$Root, $Proof) {
    if (-not $Proof -or -not $Proof.updated_at) { return $false }
    $gates = Read-Gates $Root
    if (-not $gates -or [string]::IsNullOrWhiteSpace([string]$gates.session_started)) { return $false }
    try {
        $proofAt = [datetime]::Parse([string]$Proof.updated_at)
        $sessionAt = [datetime]::Parse([string]$gates.session_started)
        return $proofAt -ge $sessionAt
    } catch { return $false }
}
function Reset-SessionGates([string]$Root) {
    $started = (Get-Date -Format o)
    $data = @{ brain_ok = $false; triage_ok = $false; brain_tunnel_ok = $false; session_started = $started; competence_recorded = $false; spec_read = $false; mdc_read = $false }
    foreach ($flag in (Get-BrainTunnelFlagNames $Root)) { $data[$flag] = $false }
    Write-Gates $Root $data
    $proof = Get-ReflectionProofPath $Root
    if (Test-Path $proof) { Remove-Item $proof -Force -ErrorAction SilentlyContinue }
}
function Reset-SessionReflectionOnly([string]$Root) {
    Reset-SessionReads $Root
}
function Reset-SessionReads([string]$Root) {
    $started = (Get-Date -Format o)
    $data = @{
        session_started = $started
        competence_recorded = $false
        spec_read = $false
        mdc_read = $false
        triage_ok = $false
        brain_tunnel_ok = $false
        read_timestamps = @{}
    }
    foreach ($flag in (Get-BrainTunnelFlagNames $Root)) { $data[$flag] = $false }
    Write-Gates $Root $data
    $proof = Get-ReflectionProofPath $Root
    if (Test-Path $proof) { Remove-Item $proof -Force -ErrorAction SilentlyContinue }
    Reset-ReadProof $Root
}
function Get-ReadProofPath([string]$Root) { return Join-Path $Root '.cursor\research\read-proof.json' }
function Read-ReadProof([string]$Root) {
    $path = Get-ReadProofPath $Root
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
}
function Reset-ReadProof([string]$Root) {
    $dir = Join-Path $Root '.cursor\research'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $gates = Read-Gates $Root
    $st = if ($gates -and $gates.session_started) { [string]$gates.session_started } else { (Get-Date -Format o) }
    @{ session_started = $st; reads = @() } | ConvertTo-Json -Depth 5 | Set-Content (Get-ReadProofPath $Root) -Encoding UTF8
}
function Append-ReadProof([string]$Root, [string]$NormPath, [hashtable]$Flags) {
    if ([string]::IsNullOrWhiteSpace($NormPath) -or $Flags.Count -eq 0) { return }
    $dir = Join-Path $Root '.cursor\research'
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $path = Get-ReadProofPath $Root
    $gates = Read-Gates $Root
    $st = if ($gates -and $gates.session_started) { [string]$gates.session_started } else { (Get-Date -Format o) }
    $doc = Read-ReadProof $Root
    $reads = @()
    if ($doc -and $doc.reads) { $reads = @($doc.reads) }
    $at = (Get-Date -Format o)
    foreach ($flag in $Flags.Keys) {
        if ($flag -notmatch '_read$') { continue }
        $reads += @{ path = $NormPath; flag = $flag; at = $at }
    }
    @{ session_started = $st; reads = $reads } | ConvertTo-Json -Depth 6 | Set-Content $path -Encoding UTF8
}
function Get-RequiredReadProofFlags([string]$Root) {
    $flags = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($f in (Get-BrainTunnelFlagNames $Root)) { [void]$flags.Add($f) }
    [void]$flags.Add('spec_read')
    return $flags
}
function Test-ReadProofComplete([string]$Root) {
    $gates = Read-Gates $Root
    if (-not $gates -or [string]::IsNullOrWhiteSpace([string]$gates.session_started)) { return $false }
    try { $sessionAt = [datetime]::Parse([string]$gates.session_started) } catch { return $false }
    $doc = Read-ReadProof $Root
    if (-not $doc -or -not $doc.reads) { return $false }
    $proved = @{}
    foreach ($entry in @($doc.reads)) {
        if (-not $entry.flag -or -not $entry.at) { continue }
        try {
            $at = [datetime]::Parse([string]$entry.at)
            if ($at -ge $sessionAt) { $proved[[string]$entry.flag] = $true }
        } catch { }
    }
    foreach ($flag in (Get-RequiredReadProofFlags $Root)) {
        if (-not $proved[$flag]) { return $false }
    }
    return $true
}
function Write-HookTelemetryLog([string]$Root, [string]$Event, [string]$Raw, [string]$Tool, [string]$Cmd, [string]$Decision, [int]$Ms) {
    try {
        $dir = Join-Path $Root '.cursor\research'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $preview = ''
        if (-not [string]::IsNullOrWhiteSpace($Cmd)) { $preview = $Cmd.Substring(0, [Math]::Min(120, $Cmd.Length)) }
        @{
            at = (Get-Date -Format o); event = $Event; tool = $Tool
            raw_len = $(if ($raw) { $raw.Length } else { 0 })
            cmd_preview = $preview; decision = $Decision; ms = $Ms
        } | ConvertTo-Json -Compress | Add-Content (Join-Path $dir "hook-telemetry-$(Get-Date -Format 'yyyy-MM-dd').jsonl") -Encoding UTF8
    } catch { }
}
function Test-ReflectionOk([string]$Root) {
    $p = Read-ReflectionProof $Root
    if (-not $p) { return @{ ok=$false; reason='reflection-proof.json absent' } }
    if (-not (Test-ReflectionSessionFresh $Root $p)) { return @{ ok=$false; reason='reflection-proof perime (session courante requise)' } }
    $comp = ''
    if ($p.tunnel -and $p.tunnel.competence) { $comp = [string]$p.tunnel.competence }
    if ([string]::IsNullOrWhiteSpace($comp)) { return @{ ok=$false; reason='competence vide' } }
    if (-not ($p.tunnel.spec -eq $true -or $p.tunnel.mdc -eq $true)) { return @{ ok=$false; reason='spec ou mdc manquant' } }
    if ($p.external.required -eq $true -and -not (Test-GithubInventoryOk $Root)) { return @{ ok=$false; reason='github-inventory manquant' } }
    return @{ ok=$true; reason='' }
}
function Test-DeleteAllowPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $p = ($Path -replace '/', '\').ToLower()
    return ($p -match '(\\|^)tests\\hooks\\') -or ($p -match '(\\|^)\.cursor\\research\\') -or ($p -match 'agent-gates\.json$')
}
function Test-TypoCarveOut([string]$Tool, $ToolInput, [string]$NormPath) {
    if ($Tool -ne 'StrReplace') { return $false }
    if (Test-ProtectedWritePath $NormPath) { return $false }
    $old = $ToolInput.old_string
    $new = $ToolInput.new_string
    if ([string]::IsNullOrWhiteSpace($old) -or [string]::IsNullOrWhiteSpace($new)) { return $false }
    if ([Math]::Abs((($new -split "`r?`n").Count) - (($old -split "`r?`n").Count)) -gt 1) { return $false }
    if ($old.Length -gt 400 -or $new.Length -gt 400) { return $false }
    return $true
}
function Test-ProtectedWritePath([string]$NormPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    return (Test-ReflectionRequiredPath $NormPath) -or (Test-SpecDomainPath $NormPath)
}
function Test-WorkspaceWritePath([string]$Root, [string]$TargetPath) {
    if ([string]::IsNullOrWhiteSpace($Root) -or [string]::IsNullOrWhiteSpace($TargetPath)) { return $false }
    try {
        $rootFull = [System.IO.Path]::GetFullPath($Root)
        $targetFull = if ([System.IO.Path]::IsPathRooted($TargetPath)) { [System.IO.Path]::GetFullPath($TargetPath) } else { [System.IO.Path]::GetFullPath((Join-Path $Root $TargetPath)) }
        $rootPrefix = $rootFull.TrimEnd('\') + '\'
        return $targetFull.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)
    } catch { return $false }
}
function Get-ExternalUnlockDir() {
    $base = [Environment]::GetFolderPath('LocalApplicationData')
    return Join-Path $base 'CursorGovernanceUnlocks'
}
function Get-ExternalUnlockPath([string]$Root) {
    $cfg = Get-MemoryConfig $Root
    $agentId = if ($cfg -and $cfg.agentId) { [string]$cfg.agentId } else { Split-Path $Root -Leaf }
    return Join-Path (Get-ExternalUnlockDir) "$agentId-unlock.json"
}
function Read-ExternalUnlock([string]$Root) {
    $path = Get-ExternalUnlockPath $Root
    if (-not (Test-Path $path)) { return $null }
    try { return Get-Content $path -Raw | ConvertFrom-Json } catch { return $null }
}
function Test-GovernancePath([string]$NormPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    $p = ($NormPath -replace '/', '\').ToLower()
    return ($p -match '(^|\\)specs\\[^\\]+\\(spec|plan|tasks)\.md$') -or
        ($p -match '(^|\\)docs\\') -or
        ($p -match '(^|\\)agents\.md$') -or
        ($p -match '(^|\\)\.cursor\\rules\\') -or
        ($p -match '(^|\\)\.cursor\\hooks\\') -or
        ($p -match '(^|\\)tests\\hooks\\')
}
function Test-ObservabilityWritePath([string]$NormPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    $p = ($NormPath -replace '/', '\').ToLower()
    return ($p -match '(^|\\)\.cursor\\research\\') -or
        ($p -match '(^|\\)reports\\hook_telemetry_') -or
        ($p -match '(^|\\)reports\\enforcement_root_cause_audit_') -or
        ($p -match '(^|\\)reports\\leak_matrix_')
}
function Test-GovernanceUnlock([string]$Root, [string]$TargetPath) {
    if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { return $true }
    $unlock = Read-ExternalUnlock $Root
    if (-not $unlock) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$unlock.expires_at)) { return $false }
    try {
        if ([datetime]::Parse([string]$unlock.expires_at) -lt (Get-Date)) { return $false }
    } catch { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$unlock.root)) { return $false }
    try {
        $unlockRoot = [System.IO.Path]::GetFullPath([string]$unlock.root)
        $rootFull = [System.IO.Path]::GetFullPath($Root)
        if (-not $unlockRoot.TrimEnd('\').Equals($rootFull.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { return $false }
    } catch { return $false }
    if (-not $unlock.scope) { return $false }
    $targetFull = if ([System.IO.Path]::IsPathRooted($TargetPath)) { [System.IO.Path]::GetFullPath($TargetPath) } else { [System.IO.Path]::GetFullPath((Join-Path $Root $TargetPath)) }
    foreach ($entry in @($unlock.scope)) {
        try {
            $scopeFull = if ([System.IO.Path]::IsPathRooted([string]$entry)) { [System.IO.Path]::GetFullPath([string]$entry) } else { [System.IO.Path]::GetFullPath((Join-Path $Root ([string]$entry))) }
            if ($targetFull.TrimEnd('\').Equals($scopeFull.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { return $true }
        } catch { }
    }
    return $false
}
function Test-WriteAllowPath([string]$Path, [string]$Root = '') {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $p = ($Path -replace '/', '\').ToLower()
    if ($p -match '\.cursor[\\/]agent-gates\.json$') { return ($env:ENFORCEMENT_MAINTENANCE -eq '1') }
    if ($p -match '00-brain-active\.mdc$') { return ($env:ENFORCEMENT_MAINTENANCE -eq '1') }
    if (Test-ObservabilityWritePath $p) { return $true }
    return $false
}
function Get-ShellCommand($Payload) {
    if (-not $Payload) { return '' }
    $cmd = ''
    if ($Payload.PSObject.Properties['command']) { $cmd = [string]$Payload.command }
    if ([string]::IsNullOrWhiteSpace($cmd) -and $Payload.tool_input) {
        $ti = $Payload.tool_input
        if ($ti -is [string]) {
            try {
                $parsed = $ti | ConvertFrom-Json
                if ($parsed.command) { $cmd = [string]$parsed.command }
                else { $cmd = $ti }
            } catch { $cmd = $ti }
        }
        elseif ($ti.command) { $cmd = [string]$ti.command }
        elseif ($ti.PSObject.Properties['cmd']) { $cmd = [string]$ti.cmd }
    }
    if ([string]::IsNullOrWhiteSpace($cmd) -and $Payload.PSObject.Properties['input']) {
        $inp = $Payload.input
        if ($inp -is [string]) { $cmd = $inp }
        elseif ($inp.command) { $cmd = [string]$inp.command }
    }
    return $cmd.Trim()
}
function Test-ShellMaintenanceAllow([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    foreach ($p in @('RECOVERY_UNLOCK','RUN_HOOK_TESTS','PREP_TERRAIN','RUN_TERRAIN_BOOTSTRAP','ISSUE_GOVERNANCE_UNLOCK')) {
        if ($Text -match $p) { return $true }
    }
    return $false
}
function Test-ShellRecoveryEntrypoint([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    foreach ($p in @('RECOVERY_UNLOCK','RUN_HOOK_TESTS','RUN_TERRAIN_BRAIN','RUN_TERRAIN_BOOTSTRAP','RUN_ANTI_LOCKOUT','PREP_TERRAIN')) {
        if ($Text -match $p) { return $true }
    }
    return $false
}
function Test-ShellManipulatesEnforcement([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    foreach ($p in @('record-brain-reads','record-reflection-proof','record-terrain-test','agent-gates\.json','reflection-proof\.json','read-proof\.json')) {
        if ($Text -match $p) { return $true }
    }
    return $false
}
function Test-ShellMutatesFile([string]$Cmd) {
    if ([string]::IsNullOrWhiteSpace($Cmd)) { return $false }
    $c = $Cmd.ToLower()
    return ($c -match 'set-content|out-file|add-content|tee-object') -or ($c -match 'copy-item|\bcopy\s|move-item|\bmove\s|rename-item|\bren\s|robocopy|xcopy') -or ($c -match 'new-item[^\r\n]*(-itemtype\s+(file|directory)|\s-force)') -or ($c -match '\|\s*set-content|[^|]>\s*[^\s&|]') -or ($c -match 'install-skills|npx[^\r\n]*\bskills\b')
}
function Test-ShellAllowWithoutTriage([string]$Cmd) {
    if ([string]::IsNullOrWhiteSpace($Cmd)) { return $false }
    if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { return $true }
    if (Test-ShellMutatesFile $Cmd) { return $false }
    foreach ($p in @('RUN_V12','RUN_HOOK','RUN_CALIBRATION','RECOVER_V10','PHASE3_V10','PHASE4_V10','verify-brain-link','verify-smoke','git\s+status','git\s+diff','schtasks')) {
        if ($Cmd -match $p) { return $true }
    }
    return $false
}
function Get-ReadFlagsForPath([string]$NormPath) {
    $flags = @{}
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $flags }
    $n = $NormPath -replace '/', '\'
    if ($n -match '(\\|^)00_INDEX\.md$') { $flags['vault_index_read'] = $true }
    if ($n -match 'henri-dusonchet\.md$') { $flags['user_profile_read'] = $true }
    if ($n -match 'erreurs[\\/]INDEX\.md$') { $flags['erreurs_index_read'] = $true }
    if ($n -match 'bibliotheque[\\/]INDEX\.md$') { $flags['biblio_index_read'] = $true }
    if ($n -match 'cursor-skills[\\/]INDEX\.md$') { $flags['skills_index_read'] = $true }
    if ($n -match 'AgentMemory[\\/]agents[\\/][^\\]+\.md$') { $flags['agent_note_read'] = $true }
    if ($n -match 'sessions[\\/]_HANDOFF\.md$') { $flags['handoff_read'] = $true }
    if ($n -match '(\\|^)AGENTS\.md$') { $flags['agents_md_read'] = $true }
    if ($n -match '(\\|^)specs\\[^\\]+\\spec\.md$') { $flags['spec_read'] = $true }
    if ($n -match '(\\|^)specs\\[^\\]+\\plan\.md$') { $flags['plan_read'] = $true }
    if ($n -match '(\\|^)specs\\[^\\]+\\tasks\.md$') { $flags['tasks_read'] = $true }
    if ($n -match '\\02_Base\\.*\.md$') { $flags['spec_read'] = $true }
    if ($n -match '(\\|^)\.cursor\\rules\\(?!00-brain-active)[^\\]+\.mdc$') { $flags['mdc_read'] = $true }
    return $flags
}




function Test-RepairSurfacePath([string]$NormPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    $p = ($NormPath -replace '/', '\').ToLower()
    return ($p -match '(^|\\)\.cursor\\hooks\\') -or ($p -match '(^|\\)\.cursor\\rules\\') -or
        ($p -match 'agent-gates\.json$') -or ($p -match '(^|\\)scripts\\run_brain_refonte') -or
        ($p -match '(^|\\)tests\\hooks\\')
}
function Test-BrainOkLoaded([string]$Root) {
    $g = Read-Gates $Root
    return ($g -and $g.brain_ok -eq $true)
}

function Get-VaultRoot([string]$Root) {
    $cfg = Get-MemoryConfig $Root
    if ($cfg -and $cfg.vaultPath -and $cfg.brainMode -eq 'central') { return [string]$cfg.vaultPath }
    return $null
}
function Test-VaultWritePath([string]$Root, [string]$TargetPath) {
    $vault = Get-VaultRoot $Root
    if ([string]::IsNullOrWhiteSpace($vault)) { return $false }
    try {
        $vaultFull = [System.IO.Path]::GetFullPath($vault).TrimEnd('\') + '\'
        $targetFull = if ([System.IO.Path]::IsPathRooted($TargetPath)) { [System.IO.Path]::GetFullPath($TargetPath) } else { [System.IO.Path]::GetFullPath((Join-Path $Root $TargetPath)) }
        return $targetFull.StartsWith($vaultFull, [StringComparison]::OrdinalIgnoreCase)
    } catch { return $false }
}
function Test-KnowledgeWritePath([string]$Root, [string]$NormPath, [string]$TargetPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    $p = ($NormPath -replace '/', '\').ToLower()
    if ($p -match '(^|[\\/])connaissances\\') { return $true }
    if ($p -match '(^|[\\/])domains\\trading\\connaissances\\') { return $true }
    if (Test-VaultWritePath $Root $TargetPath) {
        $vault = Get-VaultRoot $Root
        try {
            $vaultFull = [System.IO.Path]::GetFullPath($vault)
            $targetFull = if ([System.IO.Path]::IsPathRooted($TargetPath)) { [System.IO.Path]::GetFullPath($TargetPath) } else { [System.IO.Path]::GetFullPath((Join-Path $Root $TargetPath)) }
            $relPart = $targetFull.Substring($vaultFull.Length).TrimStart('\').ToLower()
            if ($relPart -match 'connaissances\\') { return $true }
        } catch { }
    }
    return $false
}
function Test-TradingResearchWritePath([string]$NormPath) {
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }
    $p = ($NormPath -replace '/', '\').ToLower()
    return ($p -match '(^|[\\/])docs\\analyse') -or
        ($p -match '(^|[\\/])docs\\benchmark_gex') -or
        ($p -match '(^|[\\/])specs\\010') -or
        ($p -match 'gamma-gex') -or
        ($p -match 'gamma_gex') -or
        ($p -match 'domains\\trading\\connaissances')
}
function Record-LibrarianCall([string]$Root) {
    $g = Read-Gates $Root
    $count = 0
    if ($g -and $null -ne $g.librarian_calls) { try { $count = [int]$g.librarian_calls } catch { $count = 0 } }
    Write-Gates $Root @{ librarian_used = $true; librarian_calls = ($count + 1); librarian_last_at = (Get-Date -Format o) }
}
function Test-LibrarianUsed([string]$Root) {
    $g = Read-Gates $Root
    if (-not $g) { return $false }
    if ($g.librarian_used -eq $true) { return $true }
    if ($null -ne $g.librarian_calls) { try { if ([int]$g.librarian_calls -gt 0) { return $true } } catch { } }
    return $false
}
