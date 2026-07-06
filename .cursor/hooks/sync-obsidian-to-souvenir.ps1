# Sync Obsidian vault to 01_Souvenir mirror
param(
    [string]$ProjectRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$configPath = Join-Path $ProjectRoot ".cursor\memory.config.json"
if (-not (Test-Path $configPath)) {
    Write-Error "memory.config.json not found in $ProjectRoot"
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$vault = $config.vaultPath
$souvenir = Join-Path $ProjectRoot "01_Souvenir"

function Resolve-VaultPath {
    param([string]$ConfiguredPath)

    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath)) { $candidates.Add($ConfiguredPath) }

    $homeCandidate = Join-Path $HOME 'OneDrive\Obsidian\AgentMemory'
    if (-not [string]::IsNullOrWhiteSpace($homeCandidate)) { $candidates.Add($homeCandidate) }

    if ($env:OneDrive) {
        $candidates.Add((Join-Path $env:OneDrive 'Obsidian\AgentMemory'))
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return $ConfiguredPath
}

$vault = Resolve-VaultPath -ConfiguredPath $vault

if (-not (Test-Path $vault)) {
    Write-Warning "Obsidian vault not found: $vault"
    exit 0
}

New-Item -ItemType Directory -Force -Path $souvenir | Out-Null

function Copy-IfExists {
    param([string]$Src, [string]$Dst)
    if (Test-Path $Src) {
        $dir = Split-Path $Dst -Parent
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        Copy-Item $Src $Dst -Force
    }
}

Copy-IfExists (Join-Path $vault "00_INDEX.md") (Join-Path $souvenir "00_OBSIDIAN_INDEX.md")
Copy-IfExists (Join-Path $vault "erreurs\INDEX.md") (Join-Path $souvenir "02_ERREURS_OBSIDIAN.md")
Copy-IfExists (Join-Path $vault "domains\cursor-skills\INDEX.md") (Join-Path $souvenir "domains\cursor-skills\INDEX.md")
Copy-IfExists (Join-Path $vault ($config.agentNote -replace '/', '\')) (Join-Path $souvenir "agents\$($config.agentId).md")
Copy-IfExists (Join-Path $vault "sessions\_HANDOFF.md") (Join-Path $souvenir "sessions\_HANDOFF.md")

$sessionDir = Join-Path $vault 'sessions'
if (Test-Path $sessionDir) {
    Get-ChildItem $sessionDir -File | Where-Object { $_.Name -ne '_HANDOFF.md' } |
        Sort-Object LastWriteTime -Descending | Select-Object -First 3 |
        ForEach-Object {
            Copy-IfExists $_.FullName (Join-Path $souvenir ("sessions\" + $_.Name))
        }
}

Write-Host "OK Sync Obsidian to 01_Souvenir: $souvenir"