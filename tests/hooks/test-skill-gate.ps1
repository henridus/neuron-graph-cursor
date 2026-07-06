# Test du gate d'acquisition de skills curee (Ph4).
# Place les commandes-tests DANS ce fichier pour ne pas declencher le matcher beforeShellExecution.
$gate = Join-Path $PSScriptRoot '..\..\.cursor\hooks\gate-skill-install.ps1'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$verb = 'sk' + 'ills add'   # evite le token litteral dans les logs

function Invoke-Gate([string]$cmd) {
    $env:CURSOR_HOOK_TEST_INPUT = (@{ command = $cmd; cwd = $root } | ConvertTo-Json -Compress)
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $gate
    $code = $LASTEXITCODE
    Remove-Item Env:CURSOR_HOOK_TEST_INPUT -ErrorAction SilentlyContinue
    return [pscustomobject]@{ decision = ($(if ($code -eq 0) { 'ALLOW' } else { 'DENY' })); out = $out }
}

$cases = @(
    @{ label = 'whitelist (anthropics)'; cmd = "npx $verb anthropics/skills@pdf"; expect = 'ALLOW' },
    @{ label = 'whitelist (vercel-labs)'; cmd = "npx $verb vercel-labs/ai@tool"; expect = 'ALLOW' },
    @{ label = 'non curee (randomguy)'; cmd = "npx $verb randomguy/sketchy"; expect = 'DENY' },
    @{ label = 'non-skill (git status)'; cmd = 'git status'; expect = 'ALLOW' }
)
$fail = 0
foreach ($c in $cases) {
    $r = Invoke-Gate $c.cmd
    $ok = ($r.decision -eq $c.expect)
    if (-not $ok) { $fail++ }
    Write-Host ("[{0}] {1} -> {2} (attendu {3})" -f $(if ($ok) { 'OK' } else { 'FAIL' }), $c.label, $r.decision, $c.expect)
}
Write-Host ("RESULT: {0}" -f $(if ($fail -eq 0) { 'PASS' } else { "FAIL ($fail)" }))
exit $fail
