# working-memory-sync.ps1 - memoire de travail intra-session (afterAgentResponse + preCompact)
param(
    [switch]$SessionReset,
    [string]$ProjectRoot = ''
)
$ErrorActionPreference = 'SilentlyContinue'

function Repair-Utf8Mojibake([string]$Text) {
    # Avec `powershell -File` + pipe, PowerShell draine stdin dans $input en le decodant
    # via la codepage console (souvent CP850/CP1252). Les octets UTF-8 d'origine sont donc
    # mal interpretes (ex: e-accent C3 A9 -> "|-®"). On reconstruit les octets via cette
    # codepage puis on redecode en UTF-8. No-op si le texte est ASCII pur ou deja propre.
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    if (-not ($Text -match '[^\x00-\x7F]')) { return $Text }
    try {
        $cp = [Console]::InputEncoding
        if ($null -eq $cp) { return $Text }
        if ($cp.CodePage -eq 65001 -or $cp.CodePage -eq 1200 -or $cp.CodePage -eq 1201) { return $Text }
        $bytes = $cp.GetBytes($Text)
        $strict = [Text.Encoding]::GetEncoding('utf-8', [Text.EncoderReplacementFallback]::new(''), [Text.DecoderExceptionFallback]::new())
        return $strict.GetString($bytes)
    } catch {
        return $Text
    }
}

$script:WmHookInputRaw = ''
if (-not $SessionReset) {
    $rawIn = ''
    if ($null -ne $input) {
        try {
            $parts = @($input | ForEach-Object { [string]$_ })
            if ($parts.Count -gt 0) { $rawIn = ($parts -join "`n").Trim() }
        } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($rawIn) -and [Console]::IsInputRedirected) {
        try {
            $stdin = [Console]::OpenStandardInput()
            $ms = New-Object System.IO.MemoryStream
            $stdin.CopyTo($ms)
            $bytes = $ms.ToArray()
            $ms.Dispose()
            if ($bytes.Length -gt 0) {
                $rawIn = [Text.Encoding]::UTF8.GetString($bytes)
            }
        } catch { }
    }
    if ([string]::IsNullOrWhiteSpace($rawIn) -and $null -ne $env:CURSOR_HOOK_TEST_INPUT -and $env:CURSOR_HOOK_TEST_INPUT.Trim().Length -gt 0) {
        $rawIn = $env:CURSOR_HOOK_TEST_INPUT
    }
    $script:WmHookInputRaw = Repair-Utf8Mojibake $rawIn
}

. (Join-Path $PSScriptRoot '_hook-io.ps1')

function Truncate-WmText([string]$Text, [int]$Max) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $t = $Text.Trim()
    if ($t.Length -le $Max) { return $t }
    return $t.Substring(0, $Max) + "`n...[tronque]"
}

function Get-WmHash([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    return [BitConverter]::ToString(
        [System.Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
    ).Replace('-', '').Substring(0, 16).ToLower()
}

function Read-HookInputUtf8() {
    if (-not [string]::IsNullOrWhiteSpace($script:WmHookInputRaw)) {
        return $script:WmHookInputRaw
    }
    return ''
}

function Get-WmPaths([string]$Root) {
    $research = Join-Path $Root '.cursor\research'
    if (-not (Test-Path $research)) { New-Item -ItemType Directory -Path $research -Force | Out-Null }
    return @{
        scratch = Join-Path $research 'working-memory.md'
        rule = Join-Path $Root '.cursor\rules\00-working-memory.mdc'
        meta = Join-Path $research 'working-memory-meta.json'
    }
}

function Get-AssistantTextFromPayload($payload) {
    if (-not $payload) { return '' }
    foreach ($k in @('text', 'last_message', 'assistant_message', 'message', 'response')) {
        if ($payload.PSObject.Properties[$k] -and -not [string]::IsNullOrWhiteSpace([string]$payload.$k)) {
            return [string]$payload.$k
        }
    }
    if ($payload.messages) {
        try {
            return (@($payload.messages) | ForEach-Object { [string]$_.content }) -join "`n"
        } catch { }
    }
    return ''
}

function Get-DomainFromText([string]$Text) {
    $t = ($Text + '').ToLower()
    if ($t -match 'wordpress|litespeed|flyingpress|psi|lcp|wp-admin|elementor|quic\.cloud') { return 'wordpress' }
    if ($t -match 'moonlight|sunshine|xbox|gamepad|nvidia stream') { return 'moonlight' }
    if ($t -match 'homelab|raspberry|pihole|pi-hole|usbip|tailscale|cloud-init') { return 'homelab' }
    if ($t -match 'gaming|pbo|ryzen|testmem5|overclock|schtasks.*moonlight') { return 'gaming' }
    if ($t -match 'padel|matchpoint') { return 'padel' }
    if ($t -match 'trading|gamma|vwap') { return 'trading' }
    if ($t -match 'cursor|hook|enforcement|brain|vault|obsidian|librarian') { return 'automation' }
    return 'general'
}

function Get-WmMutexName([string]$Root) {
    $cfg = Get-MemoryConfig $Root
    $id = 'agent'
    if ($cfg -and $cfg.agentId) { $id = [string]$cfg.agentId }
    $safe = ($id -replace '[^a-zA-Z0-9\-]', '-').ToLower()
    if ([string]::IsNullOrWhiteSpace($safe)) { $safe = 'agent' }
    return "Global\wm-sync-$safe"
}

function Read-WmMeta([string]$Path) {
    $defaults = @{
        turns = 0
        last_hash = ''
        last_promote_at = ''
        domain = 'general'
        structured_hash = ''
        structured_at_turn = 0
        turns_since_structured = 0
    }
    if (-not (Test-Path $Path)) { return $defaults }
    try {
        $o = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
        return @{
            turns = [int](if ($null -ne $o.turns) { $o.turns } else { 0 })
            last_hash = [string](if ($o.last_hash) { $o.last_hash } else { '' })
            last_promote_at = [string](if ($o.last_promote_at) { $o.last_promote_at } else { '' })
            domain = [string](if ($o.domain) { $o.domain } else { 'general' })
            structured_hash = [string](if ($o.structured_hash) { $o.structured_hash } else { '' })
            structured_at_turn = [int](if ($null -ne $o.structured_at_turn) { $o.structured_at_turn } else { 0 })
            turns_since_structured = [int](if ($null -ne $o.turns_since_structured) { $o.turns_since_structured } else { 0 })
        }
    } catch { return $defaults }
}

function Write-WmMeta([string]$Path, [hashtable]$Data) {
    [System.IO.File]::WriteAllText($Path, ($Data | ConvertTo-Json -Compress), [Text.UTF8Encoding]::new($false))
}

function Count-JournalLines([string]$Body) {
    $count = 0
    $inJournal = $false
    foreach ($line in ($Body -split "`r?`n")) {
        if ($line -match '^## Journal des tours') { $inJournal = $true; continue }
        if ($inJournal -and $line.Trim() -match '^\-\s+\[') { $count++ }
    }
    return $count
}

function Get-StructuredScratch([string]$Existing) {
    $header = @(
        '# Working Memory (session courante)',
        '',
        '> Scratchpad vivant - complete par l agent ET le hook afterAgentResponse/preCompact.',
        '',
        '## Objectif',
        '- (a completer)',
        '',
        '## Decisions',
        '- (a completer)',
        '',
        '## Faits etablis',
        '- (a completer)',
        '',
        '## Blocage courant',
        '- none',
        '',
        '## Prochaine etape',
        '- (a completer)',
        '',
        '## Journal des tours (hook)',
        ''
    ) -join "`n"
    if ([string]::IsNullOrWhiteSpace($Existing)) { return $header }
    return (Repair-WorkingMemoryBody $Existing)
}

function Repair-WorkingMemoryBody([string]$Body) {
    if ([string]::IsNullOrWhiteSpace($Body)) { return (Get-StructuredScratch '') }
    $marker = '## Journal des tours (hook)'
    $parts = $Body -split [regex]::Escape($marker)
    $head = $parts[0].TrimEnd()
    $journalLines = [System.Collections.Generic.List[string]]::new()
    if ($parts.Count -gt 1) {
        for ($i = 1; $i -lt $parts.Count; $i++) {
            foreach ($line in ($parts[$i] -split "`r?`n")) {
                $t = $line.Trim()
                if ($t.Length -gt 0 -and $t -notmatch '^\.\.\.\[tronque\]') {
                    $journalLines.Add($t)
                }
            }
        }
    }
    $seen = @{}
    $unique = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $journalLines) {
        if (-not $seen.ContainsKey($line)) {
            $seen[$line] = $true
            $unique.Add($line)
        }
    }
    if ($unique.Count -gt 12) {
        $unique = [System.Collections.Generic.List[string]]::new(@($unique[($unique.Count - 12)..($unique.Count - 1)]))
    }
    if ($head -notmatch [regex]::Escape($marker)) {
        $journalText = if ($unique.Count -gt 0) { ($unique -join "`n") + "`n" } else { '' }
        return ($head + "`n`n" + $marker + "`n`n" + $journalText)
    }
    return $Body
}

function Get-StructuredBlock([string]$Body) {
    $marker = '## Journal des tours (hook)'
    if ($Body -match [regex]::Escape($marker)) {
        return ($Body -split [regex]::Escape($marker), 2)[0].Trim()
    }
    return $Body.Trim()
}

function Append-TurnJournal([string]$Body, [string]$Entry) {
    $Body = Repair-WorkingMemoryBody $Body
    $marker = '## Journal des tours (hook)'
    $parts = $Body -split [regex]::Escape($marker), 2
    $head = $parts[0].TrimEnd()
    $journal = if ($parts.Count -gt 1) { $parts[1] } else { '' }
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($journal -split "`r?`n")) {
        $t = $line.Trim()
        if ($t.Length -gt 0 -and $t -notmatch '^\.\.\.\[tronque\]') { $lines.Add($t) }
    }
    if ($lines -notcontains $Entry) { $lines.Add($Entry) }
    $seen = @{}
    $unique = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        if (-not $seen.ContainsKey($line)) {
            $seen[$line] = $true
            $unique.Add($line)
        }
    }
    if ($unique.Count -gt 12) {
        $unique = [System.Collections.Generic.List[string]]::new(@($unique[($unique.Count - 12)..($unique.Count - 1)]))
    }
    return ($head + "`n`n" + $marker + "`n`n" + ($unique -join "`n") + "`n")
}

function Write-WorkingMemoryRule {
    param(
        [string]$RulePath,
        [string]$ScratchPath,
        [string]$AgentId,
        [string]$Domain,
        [int]$TurnsSinceStructured = 0
    )
    $scratch = ''
    if (Test-Path $ScratchPath) {
        try { $scratch = [System.IO.File]::ReadAllText($ScratchPath, [Text.UTF8Encoding]::new($false)) } catch { $scratch = '' }
    }
    $nudge = ''
    if ($TurnsSinceStructured -ge 3) {
        $nudge = "RAPPEL: Faits etablis non mis a jour depuis $TurnsSinceStructured tours - verifier Objectif/Decisions/Faits/Blocage avant de continuer."
    }
    $inject = Truncate-WmText $scratch 2000
    $lines = @(
        '---',
        'alwaysApply: true',
        'description: "Memoire active reinjectee chaque tour (hook working-memory-sync)"',
        '---',
        '',
        "# Memoire active - $AgentId",
        '',
        "Domaine: $Domain | Source: .cursor/research/working-memory.md",
        ''
    )
    if ($nudge) { $lines += $nudge; $lines += '' }
    $lines += @(
        '**Relire ce bloc avant toute action significative.**',
        '',
        '## Etat courant',
        '',
        $inject
    )
    [System.IO.File]::WriteAllText($RulePath, ($lines -join "`n"), [Text.UTF8Encoding]::new($false))
}

function Promote-WorkingMemoryToVault([string]$Root, [string]$ScratchPath, [string]$Domain, [string]$Suffix) {
    $cfg = Get-MemoryConfig $Root
    if (-not $cfg -or -not $cfg.vaultPath) { return $false }
    $vault = [string]$cfg.vaultPath
    if (-not (Test-Path $vault)) { return $false }
    if (-not (Test-Path $ScratchPath)) { return $false }
    $content = ''
    try { $content = [System.IO.File]::ReadAllText($ScratchPath, [Text.UTF8Encoding]::new($false)) } catch { return $false }
    if ([string]::IsNullOrWhiteSpace($content) -or $content.Length -lt 80) { return $false }
    $date = Get-Date -Format 'yyyy-MM-dd'
    $topic = if ($Domain -eq 'general') { 'session' } else { $Domain }
    $name = if ($Suffix) { "$date-$topic-wm-$Suffix.md" } else { "$date-$topic-wm.md" }
    $destDir = Join-Path $vault 'sessions'
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null
    $dest = Join-Path $destDir $name
    $agentId = if ($cfg.agentId) { [string]$cfg.agentId } else { 'agent' }
    $yaml = @(
        '---',
        'type: session',
        "agentId: $agentId",
        "domaine: $Domain",
        "date: $date",
        'status: checkpoint',
        'tags:',
        '  - working-memory',
        '---',
        '',
        "# Working memory checkpoint - $topic",
        '',
        $content
    ) -join "`n"
    [System.IO.File]::WriteAllText($dest, $yaml, [Text.UTF8Encoding]::new($false))
    return $true
}

function Invoke-WorkingMemorySyncCore {
    param(
        [string]$Root,
        [string]$EventName = 'afterAgentResponse',
        [string]$AssistantText = '',
        [string]$Status = 'completed'
    )
    if ($Status -eq 'aborted') { return }
    $paths = Get-WmPaths $Root
    $cfg = Get-MemoryConfig $Root
    $agentId = if ($cfg -and $cfg.agentId) { [string]$cfg.agentId } else { 'agent' }
    $meta = Read-WmMeta $paths.meta
    $domain = Get-DomainFromText $AssistantText
    if ($domain -eq 'general' -and $meta.domain -ne 'general') { $domain = $meta.domain }

    $body = ''
    if (Test-Path $paths.scratch) {
        try { $body = [System.IO.File]::ReadAllText($paths.scratch, [Text.UTF8Encoding]::new($false)) } catch { $body = '' }
    }
    $body = Get-StructuredScratch $body
    $structuredBlock = Get-StructuredBlock $body
    $structuredHash = Get-WmHash $structuredBlock

    $snippet = Truncate-WmText ($AssistantText -replace '\s+', ' ').Trim() 220
    $addedTurn = $false
    if ($snippet.Length -gt 20) {
        $hash = Get-WmHash $snippet
        $at = Get-Date -Format 'HH:mm:ss'
        $entry = "- [$at] ($EventName) $snippet"
        $journalBefore = @((($body -split '## Journal des tours \(hook\)', 2)[1] -split "`r?`n") | Where-Object { $_.Trim() -match '^\-\s+\[' })
        $body = Append-TurnJournal $body $entry
        $journalAfter = @((($body -split '## Journal des tours \(hook\)', 2)[1] -split "`r?`n") | Where-Object { $_.Trim() -match '^\-\s+\[' })
        if ($journalAfter.Count -gt $journalBefore.Count) {
            $meta.turns = [int]$meta.turns + 1
            $meta.last_hash = $hash
            $addedTurn = $true
        }
    }

    if ([string]::IsNullOrEmpty([string]$meta.structured_hash)) {
        $meta.structured_hash = $structuredHash
    } elseif ($structuredHash -ne $meta.structured_hash) {
        $meta.structured_hash = $structuredHash
        $meta.structured_at_turn = Count-JournalLines $body
    }

    $head = Get-StructuredBlock $body
    $journalPart = ''
    if ($body -match '## Journal des tours \(hook\)') {
        $journalPart = ($body -split '## Journal des tours \(hook\)', 2)[1]
    }
    $body = ($head + "`n`n## Journal des tours (hook)`n" + $journalPart).TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($paths.scratch, $body, [Text.UTF8Encoding]::new($false))
    $meta.turns = Count-JournalLines $body
    $meta.turns_since_structured = [Math]::Max(0, [int]$meta.turns - [int]$meta.structured_at_turn)
    Write-WorkingMemoryRule $paths.rule $paths.scratch $agentId $domain ([int]$meta.turns_since_structured)

    $promoteEvery = 5
    if ($meta.turns -gt 0 -and ($meta.turns % $promoteEvery) -eq 0 -and $addedTurn) {
        $suffix = "t$($meta.turns)"
        if (Promote-WorkingMemoryToVault $Root $paths.scratch $domain $suffix) {
            $meta.last_promote_at = (Get-Date -Format o)
        }
    }
    $meta.domain = $domain
    Write-WmMeta $paths.meta $meta
}

function Invoke-WorkingMemorySync {
    param(
        [string]$Root,
        [string]$EventName = 'afterAgentResponse',
        [string]$AssistantText = '',
        [string]$Status = 'completed'
    )
    $mutex = $null
    $locked = $false
    try {
        $mutexName = Get-WmMutexName $Root
        $mutex = New-Object System.Threading.Mutex($false, $mutexName)
        $locked = $mutex.WaitOne(3000)
        if (-not $locked) { return }
        Invoke-WorkingMemorySyncCore -Root $Root -EventName $EventName -AssistantText $AssistantText -Status $Status
    } catch { }
    finally {
        if ($locked -and $mutex) {
            try { $mutex.ReleaseMutex() } catch { }
        }
        if ($mutex) { $mutex.Dispose() }
    }
}

function Reset-WorkingMemorySession([string]$Root) {
    $paths = Get-WmPaths $Root
    $cfg = Get-MemoryConfig $Root
    $agentId = if ($cfg -and $cfg.agentId) { [string]$cfg.agentId } else { 'agent' }

    if (Test-Path $paths.scratch) {
        $old = [System.IO.File]::ReadAllText($paths.scratch, [Text.UTF8Encoding]::new($false))
        if ($old -and $old.Length -gt 80) {
            $domain = 'general'
            $m = Read-WmMeta $paths.meta
            if ($m.domain) { $domain = $m.domain }
            Promote-WorkingMemoryToVault $Root $paths.scratch $domain 'closeout' | Out-Null
        }
    }

    $fresh = Get-StructuredScratch ''
    [System.IO.File]::WriteAllText($paths.scratch, $fresh, [Text.UTF8Encoding]::new($false))
    Write-WmMeta $paths.meta @{
        turns = 0
        last_hash = ''
        last_promote_at = ''
        domain = 'general'
        structured_hash = ''
        structured_at_turn = 0
        turns_since_structured = 0
    }
    Write-WorkingMemoryRule $paths.rule $paths.scratch $agentId 'general' 0
}

if ($SessionReset) {
    $r = if (-not [string]::IsNullOrWhiteSpace($ProjectRoot)) { $ProjectRoot } else { (Get-Location).Path }
    try { Reset-WorkingMemorySession $r } catch { }
    exit 0
}

# --- entry (hook) ---
$inputRaw = Select-HookJsonPayload (Read-HookInputUtf8)
if ([string]::IsNullOrWhiteSpace($inputRaw)) { exit 0 }

$projectRoot = (Get-Location).Path
$status = 'completed'
$eventName = 'afterAgentResponse'
$assistantText = ''

try {
    $payload = $inputRaw | ConvertFrom-Json
    if ($payload.cwd) { $projectRoot = [string]$payload.cwd }
    if ($payload.status) { $status = [string]$payload.status }
    if ($payload.event) { $eventName = [string]$payload.event }
    if ($payload.trigger) { $eventName = [string]$payload.trigger }
    $assistantText = Get-AssistantTextFromPayload $payload
    if ($assistantText.Length -gt 20 -and $eventName -eq 'stop' -and -not $payload.status) {
        $eventName = 'afterAgentResponse'
    }
} catch { exit 0 }

if ($eventName -match 'compact|preCompact') { $eventName = 'preCompact' }
if ($eventName -eq 'stop' -and $assistantText.Length -le 20) { exit 0 }

try {
    $debugDir = Join-Path $projectRoot '.cursor\research'
    if (-not (Test-Path $debugDir)) { New-Item -ItemType Directory -Path $debugDir -Force | Out-Null }
    $debugLine = (@{
        at = (Get-Date -Format o)
        event = $eventName
        status = $status
        text_len = $assistantText.Length
        text_preview = (Truncate-WmText $assistantText 120)
    } | ConvertTo-Json -Compress)
    Add-Content (Join-Path $debugDir 'wm-hook-debug.jsonl') -Value $debugLine -Encoding UTF8
} catch { }

try {
    Invoke-WorkingMemorySync -Root $projectRoot -EventName $eventName -AssistantText $assistantText -Status $status
} catch { }

exit 0
