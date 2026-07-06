# beforeShellExecution - marque recherche externe GitHub dans reflection-proof
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot '_hook-io.ps1')

$raw = Read-HookInput
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
try { $in = $raw | ConvertFrom-Json } catch { exit 0 }

$cmd = ''
if ($in.command) { $cmd = $in.command }
elseif ($in.tool_input.command) { $cmd = $in.tool_input.command }
if ([string]::IsNullOrWhiteSpace($cmd)) { exit 0 }

$root = Get-ProjectRoot $(if ($in.cwd) { $in.cwd } else { (Get-Location).Path })

$isGithub = $false
if ($cmd -match 'run-phase2-github-research') { $isGithub = $true }
if ($cmd -match 'api\.github\.com') { $isGithub = $true }
if ($cmd -match 'github-search') { $isGithub = $true }

$isWeb = $false
if ($cmd -match 'WebSearch|web_search|flashalpha\.com|spotgamma\.com|crosstrade\.io') { $isWeb = $true }

if ($isGithub) { Update-ReflectionExternal $root @{ github = $true } }
if ($isWeb) { Update-ReflectionExternal $root @{ web = $true } }

exit 0
