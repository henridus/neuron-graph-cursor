# beforeShellExecution V17 - acquisition de skills curee (fail-open)
# Autorise l'install si l'auteur (owner) est dans la whitelist du cerveau ; sinon deny + propose.
$ErrorActionPreference = 'SilentlyContinue'
if ($env:ENFORCEMENT_MAINTENANCE -eq '1') { '{"permission":"allow"}' | Write-Output; exit 0 }
try {
    . (Join-Path $PSScriptRoot '_hook-io.ps1')
    $raw = Read-HookInput
    $root = Get-ProjectRoot (Get-Location).Path
    $cmd = ''
    if (-not [string]::IsNullOrWhiteSpace($raw)) {
        try { $in = $raw | ConvertFrom-Json; if ($in.cwd) { $root = Get-ProjectRoot $in.cwd }; $cmd = Get-ShellCommand $in } catch { }
    }
    # N'agit que sur les commandes d'installation de skill
    if ([string]::IsNullOrWhiteSpace($cmd)) { Out-Allow }
    if ($cmd -notmatch '(?i)skills?\s+add|install-skills') { Out-Allow }

    # Whitelist : vault domains/cursor-skills/whitelist.json, sinon defauts
    $authors = @('anthropics','anthropic','vercel-labs','cursor','getcursor','modelcontextprotocol','obsidianmd','openai')
    try {
        $cfg = Get-MemoryConfig $root
        if ($cfg -and $cfg.vaultPath) {
            $wl = Join-Path $cfg.vaultPath 'domains\cursor-skills\whitelist.json'
            if (Test-Path $wl) {
                $j = Get-Content $wl -Raw | ConvertFrom-Json
                if ($j.authors) { $authors = @($j.authors) }
            }
        }
    } catch { }
    $authorsLc = $authors | ForEach-Object { ([string]$_).ToLower() }

    # Extraire les tokens owner/repo[@skill]
    $rx = [regex]'([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(@[A-Za-z0-9_.-]+)?'
    $ms = $rx.Matches($cmd)
    if ($ms.Count -eq 0) { Out-Allow }  # non parsable : ne pas bloquer (fail-open)
    $bad = @()
    foreach ($m in $ms) {
        $owner = $m.Groups[1].Value.ToLower()
        if ($authorsLc -notcontains $owner) { $bad += $m.Value }
    }
    if ($bad.Count -eq 0) { Out-Allow }
    Out-Deny 'Skill non curee' ("Auteur(s) hors whitelist: " + ($bad -join ', ') + ". Options: (1) proposer a l'operateur, (2) ajouter l'auteur a domains/cursor-skills/whitelist.json si de confiance. Whitelist: " + ($authorsLc -join ', '))
} catch { '{"permission":"allow"}' | Write-Output; exit 0 }
