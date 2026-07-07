# Enregistre issue competence + meta reflexion (audit/plan/spec write)
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('competence_deja_disponible', 'skill_a_importer', 'skill_a_adapter', 'nouvelle_solution_justifiee')]
    [string]$Competence,
    [string]$Domaine = '',
    [ValidateSet('audit', 'plan', 'implementation', 'pending')]
    [string]$TaskType = 'audit',
    [switch]$ExternalRequired,
    [switch]$ExternalWeb
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\.cursor\hooks\_hook-io.ps1')

$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $root 'AGENTS.md'))) {
    Write-Error 'Lancer depuis racine projet agent (AGENTS.md requis).'
}

if (-not (Read-ReflectionProof $root)) {
    Init-ReflectionProof $root $(if ($Domaine) { $Domaine } else { 'general' }) $true
}

$tunnel = @{ competence = $Competence }
$gates = Read-Gates $root
if ($gates) {
    if ($gates.spec_read -eq $true) { $tunnel.spec = $true }
    if ($gates.mdc_read -eq $true) { $tunnel.mdc = $true }
    if ($gates.skills_index_read -eq $true) { $tunnel.skills = $true }
}
Update-ReflectionTunnel $root $tunnel

$data = @{ task_type = $TaskType }
if ($Domaine) { $data.domaine = $Domaine }
if ($ExternalRequired) { Update-ReflectionExternal $root @{ required = $true } }
if ($ExternalWeb) { Update-ReflectionExternal $root @{ web = $true } }
Write-ReflectionProof $root $data

Write-Host "OK reflection-proof: competence=$Competence task_type=$TaskType"
