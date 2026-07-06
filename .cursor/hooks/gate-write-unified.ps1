# preToolUse V18 — hybrid brain lever (governance + tunnel + reflection + librarian)
$ErrorActionPreference = 'SilentlyContinue'
if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { '{"permission":"allow"}' | Write-Output; exit 0 }
try {
    . (Join-Path $PSScriptRoot '_hook-io.ps1')
    $raw = Read-HookInput
    if ([string]::IsNullOrWhiteSpace($raw)) { Out-Allow }
    try { $in = $raw | ConvertFrom-Json } catch { Out-Allow }
    $tool = $in.tool_name
    if ($tool -notin @('Write','StrReplace','EditNotebook')) { Out-Allow }
    $toolInput = $in.tool_input
    $target = ''
    if ($toolInput.PSObject.Properties['path']) { $target = $toolInput.path }
    elseif ($toolInput.PSObject.Properties['file_path']) { $target = $toolInput.file_path }
    elseif ($toolInput.PSObject.Properties['target_notebook']) { $target = $toolInput.target_notebook }
    if ([string]::IsNullOrWhiteSpace($target)) { Out-Deny 'Cible Write absente' 'path requis' }
    $root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { (Get-Location).Path })
    $norm = ($target -replace '/','\').ToLower()
    if (Test-ObservabilityWritePath $norm) { Out-Allow }
    if (Test-WriteAllowPath $target $root) { Out-Allow }
    $inVault = Test-VaultWritePath $root $target
    if (-not (Test-WorkspaceWritePath $root $target) -and -not $inVault) { Out-Deny 'Hors workspace' 'Write sous racine projet ou vault central.' }
    if (-not (Test-BrainActive $root)) { Out-Deny 'Brain non charge' 'sessionStart requis.' }

    $isGov = Test-GovernancePath $norm
    $isProt = Test-ProtectedWritePath $norm
    $isKnow = Test-KnowledgeWritePath $root $norm $target

    if ($isProt -or $isGov) {
        if (-not (Test-BrainOkLoaded $root)) {
            Out-Deny 'Tunnel cerveau incomplet' 'sessionStart / gates requis.'
        }
        if ($isProt -and -not (Test-BrainTunnelOk $root)) {
            Out-Deny 'Tunnel cerveau incomplet' 'Lire requiredReads vault avant Write spec/docs.'
        }
        if ($isGov -and -not (Test-GovernanceUnlock $root $target)) {
            Out-Deny 'Unlock gouvernance requis' 'Fichier gouvernance: ISSUE_GOVERNANCE_UNLOCK.ps1'
        }
        if ($isProt) {
            $refl = Test-ReflectionOk $root
            if (-not $refl.ok) {
                Out-Deny 'Preuve reflexion requise' ("record-reflection-proof.ps1 : $($refl.reason)")
            }
        }
    }

    if ($isKnow -and -not (Test-LibrarianUsed $root)) {
        Out-Deny 'Traversee cerveau requise' 'Appeler library_traverse depuis MAP-<domaine> (librarian MCP) avant Write connaissances.'
    }

    if ($norm -match 'agent-gates\.json$' -and $env:ENFORCEMENT_MAINTENANCE -ne '1') {
        Out-Deny 'agent-gates protege' 'Ecriture agent-gates hors maintenance interdite.'
    }
    if ($norm -match '00-brain-active\.mdc$' -and $env:ENFORCEMENT_MAINTENANCE -ne '1') {
        Out-Deny 'brain-active protege' 'Ecriture brain-active hors maintenance interdite.'
    }

    if (Test-RepairSurfacePath $norm -and $env:ENFORCEMENT_MAINTENANCE -eq '1') { Out-Allow }
    if (-not (Test-BrainTunnelOk $root)) { Out-Deny 'Tunnel cerveau incomplet' 'Lire requiredReads vault avant Write.' }
    if (-not (Test-BrainOkLoaded $root)) { Out-Deny 'Brain non charge' 'Attendre injection cerveau (sessionStart).' }
    if (Test-TypoCarveOut $tool $toolInput $norm) { Out-Allow }
    Out-Allow
} catch { '{"permission":"allow"}' | Write-Output; exit 0 }
