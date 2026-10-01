$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../lib/check-policy.ps1')
$hub = Get-CheckPolicy -Repo 'alawein/career-engine' -Class tool -Language typescript -CheckProfile hub-check
if (($hub.RequiredChecks -join ',') -ne 'check') { throw 'wrong hub checks' }
if ($hub.WorkflowPath -ne '.github/workflows/check.yml') { throw 'wrong workflow' }
if (-not $hub.RequireChecks) { throw 'hub check not required' }
$rejected = $false
try { Get-CheckPolicy -Repo 'alawein/meshal-site' -Class site -Language typescript -CheckProfile hub-check }
catch { $rejected = $true }
if (-not $rejected) { throw 'accepted incompatible profile' }
Write-Host 'PASS: hub policy helper'

foreach ($case in @(
  @{ Class='tool'; Language='typescript'; Profile='standard'; Strict=$false; Checks='markdown-lint,link-check,actionlint,pr-title,node-ci'; Path='.github/workflows/ci.yml'; Required=$false },
  @{ Class='tool'; Language='python'; Profile='standard'; Strict=$true; Checks='markdown-lint,link-check,actionlint,pr-title,python-ci'; Path='.github/workflows/ci.yml'; Required=$true },
  @{ Class='site'; Language='typescript'; Profile='standard'; Strict=$false; Checks='markdown-lint,link-check,actionlint,pr-title,node-ci'; Path='.github/workflows/ci.yml'; Required=$true }
)) {
  $policy = Get-CheckPolicy -Repo 'alawein/example' -Class $case.Class -Language $case.Language -CheckProfile $case.Profile -Strict:$case.Strict
  if (($policy.RequiredChecks -join ',') -ne $case.Checks -or $policy.WorkflowPath -ne $case.Path -or $policy.RequireChecks -ne $case.Required) { throw 'standard policy changed' }
}
foreach ($invalid in @(
  @{ Repo='alawein/other'; Class='tool'; Language='typescript' },
  @{ Repo='alawein/career-engine'; Class='site'; Language='typescript' },
  @{ Repo='alawein/career-engine'; Class='tool'; Language='python' }
)) {
  $rejected = $false
  try { Get-CheckPolicy -Repo $invalid.Repo -Class $invalid.Class -Language $invalid.Language -CheckProfile hub-check | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { throw 'hub accepted unsupported input' }
}
Write-Host 'PASS: standard behavior and hub compatibility'

$ruleRoot = Join-Path $PSScriptRoot '../../rulesets'
foreach ($spec in @(
  @{ File='main-hub.json'; Checks='check'; Rules='deletion,non_fast_forward,required_status_checks' },
  @{ File='main-site.json'; Checks='markdown-lint,link-check,actionlint,pr-title,node-ci'; Rules='deletion,non_fast_forward,required_linear_history,pull_request,required_status_checks' }
)) {
  $rule = Get-Content -LiteralPath (Join-Path $ruleRoot $spec.File) -Raw | ConvertFrom-Json
  $types = @($rule.rules | ForEach-Object { $_.type })
  $contexts = @($rule.rules | Where-Object { $_.type -eq 'required_status_checks' } | ForEach-Object { $_.parameters.required_status_checks } | ForEach-Object { $_.context })
  if ($rule.name -ne 'main-guard' -or $rule.enforcement -ne 'active' -or @($rule.bypass_actors).Count -ne 0 -or $rule.target -ne 'branch' -or (@($rule.conditions.ref_name.include) -join ',') -ne 'refs/heads/main') { throw "$($spec.File) has incorrect guard" }
  if (($types -join ',') -ne $spec.Rules -or ($contexts -join ',') -ne $spec.Checks) { throw "$($spec.File) has incorrect rules or checks" }
}
Write-Host 'PASS: hub and site ruleset fixtures'

$pwshPath = (Get-Command pwsh -ErrorAction Stop).Source
$savedPath = $env:PATH
$env:FAKE_PWSH = $pwshPath
$env:PATH = "$PSScriptRoot;$env:WINDIR\System32;$(Split-Path -Parent $pwshPath)"
$fakeCommand = Get-Command gh -ErrorAction Stop
if ($fakeCommand.Source -ne (Join-Path $PSScriptRoot 'gh.cmd') -or (Get-Command gh.exe -ErrorAction SilentlyContinue)) { throw 'fake gh command did not resolve safely' }
$env:FAKE_GH_LOG = Join-Path $env:TEMP 'kit-check-policy-fake-gh.log'
$scripts = Split-Path -Parent $PSScriptRoot
function Invoke-PolicyScript([string]$Name, [string]$Case, [string]$Repo, [string]$Class, [string]$Profile, [switch]$Strict) {
  $env:FAKE_GH_CASE = $Case
  Set-Content -LiteralPath $env:FAKE_GH_LOG -Value ''
  $extraArgs = @()
  if ($Strict) { $extraArgs += '-Strict' }
  $output = (& $pwshPath -NoProfile -File (Join-Path $scripts $Name) -Repo $Repo -Class $Class -CheckProfile $Profile @extraArgs 2>&1 | Out-String)
  $code = $LASTEXITCODE
  $calls = Get-Content -LiteralPath $env:FAKE_GH_LOG -Raw
  if ($calls -match '(?m)^api\s+-X\s+|(?m)^api\s+--method\s+|(?m)^api\s+.*--input') { throw "$Name attempted a mutation" }
  return [pscustomobject]@{ Out=$output; Code=$code; Calls=$calls }
}
try {
  # Supplemental-label failure, or weakened canonical validation, must fail these real audit cases.
  $supplemental = Invoke-PolicyScript 'verify-repo.ps1' 'labels-extra' 'alawein/example' 'docs' 'standard'
  if ($supplemental.Code -ne 0 -or $supplemental.Out -notmatch '(?m)^NOTE\s+additional labels:' -or $supplemental.Out -match '(?m)^FAIL|delete by hand') { throw "supplemental labels incorrectly fail the audit: $($supplemental.Out.Trim())" }
  foreach ($label in @('feat', 'fix', 'docs', 'chore', 'blocked')) {
    if ($supplemental.Out -notmatch "(?m)^PASS\s+label ${label}:") { throw "canonical label $label was not validated" }
  }
  foreach ($label in @('dependencies', 'accessibility', 'javascript')) {
    if ($supplemental.Out -notmatch "(?m)^NOTE\s+additional labels:[^\r\n]*$label") { throw "supplemental label $label was not reported" }
  }
  foreach ($case in @('labels-missing', 'labels-color', 'labels-description')) {
    $invalid = Invoke-PolicyScript 'verify-repo.ps1' $case 'alawein/example' 'docs' 'standard'
    if ($invalid.Code -ne 1 -or $invalid.Out -notmatch '(?m)^FAIL\s+label fix:' -or ([regex]::Matches($invalid.Out, '(?m)^FAIL')).Count -ne 1 -or $invalid.Out -notmatch '(?m)^NOTE\s+additional labels:') { throw "$case did not preserve the canonical-label failure" }
  }
  Write-Host 'PASS: supplemental label note and canonical missing, color, description failures'
  $siteNoStatus = Invoke-PolicyScript 'verify-repo.ps1' 'site' 'alawein/meshal-site' 'site' 'standard'
  if ($siteNoStatus.Out -notmatch 'FAIL[^\r\n]*main-guard rule required_status_checks' -or $siteNoStatus.Out -notmatch 'FAIL[^\r\n]*main-guard required checks') { throw 'ready site without required checks passed policy audit' }
  $siteBootstrap = Invoke-PolicyScript 'verify-repo.ps1' 'site-missing-ci' 'alawein/meshal-site' 'site' 'standard'
  if ($siteBootstrap.Out -notmatch 'FAIL[^\r\n]*ci\.yml with the required jobs' -or $siteBootstrap.Out -notmatch 'NOTE[^\r\n]*main-guard required checks' -or $siteBootstrap.Out -match 'FAIL[^\r\n]*main-guard rule required_status_checks') { throw 'absent CI bootstrap contract changed' }
  $siteWrong = Invoke-PolicyScript 'verify-repo.ps1' 'site-wrong' 'alawein/meshal-site' 'site' 'standard'
  if ($siteWrong.Out -notmatch 'FAIL[^\r\n]*main-guard required checks[^\r\n]*wrong-ci') { throw 'site audit accepted wrong exact context' }
  $siteReady = Invoke-PolicyScript 'verify-repo.ps1' 'site-ready' 'alawein/meshal-site' 'site' 'standard'
  if ($siteReady.Out -match 'FAIL[^\r\n]*main-guard (?:rule required_status_checks|required checks)' -or $siteReady.Out -notmatch 'PASS[^\r\n]*main-guard required checks') { throw 'site audit rejected ready exact contexts' }
  $strictTool = Invoke-PolicyScript 'verify-repo.ps1' 'private-tool' 'alawein/example' 'tool' 'standard' -Strict
  if ($strictTool.Out -notmatch 'FAIL[^\r\n]*main-guard rule required_status_checks' -or $strictTool.Out -notmatch 'FAIL[^\r\n]*main-guard required checks') { throw 'ready strict tool without required checks passed policy audit' }
  $excluded = Invoke-PolicyScript 'verify-repo.ps1' 'hub-excluded' 'alawein/career-engine' 'tool' 'hub-check'
  if ($excluded.Code -eq 0 -or $excluded.Out -notmatch 'FAIL[^\r\n]*main-guard ref') { throw 'hub verification accepted excluded main' }
  foreach ($name in @('setup-repo.ps1', 'verify-repo.ps1')) {
    $missing = Invoke-PolicyScript $name 'hub-missing' 'alawein/career-engine' 'tool' 'hub-check'
    if ($missing.Out -notmatch 'FAIL[^\r\n]*check\.yml' -or $missing.Code -eq 0) { throw "$name omitted missing check.yml failure" }
    $wrong = Invoke-PolicyScript $name 'hub-wrong' 'alawein/career-engine' 'tool' 'hub-check'
    if ($wrong.Out -notmatch 'FAIL[^\r\n]*check\.yml' -or $wrong.Code -eq 0) { throw "$name accepted wrong check name" }
    $good = Invoke-PolicyScript $name 'hub-good' 'alawein/career-engine' 'tool' 'hub-check'
    if ($good.Out -notmatch 'check\.yml' -or $good.Out -notmatch 'check') { throw "$name ignored hub workflow" }
    if ($good.Calls -notmatch 'contents/\.github/workflows/check\.yml') { throw "$name did not read check.yml" }
    if ($name -eq 'setup-repo.ps1') {
      if ($good.Out -notmatch '(?m)^DRY\s+gh api -X (?:PUT|POST) repos/alawein/career-engine/rulesets(?:/1)? --input -\s+<-\s+(.+)$') { throw 'hub plan has no main-guard payload' }
      $planned = $Matches[1] | ConvertFrom-Json
      $types = @($planned.rules | ForEach-Object { $_.type })
      $status = @($planned.rules | Where-Object { $_.type -eq 'required_status_checks' })
      $contexts = @($status[0].parameters.required_status_checks | ForEach-Object { $_.context })
      if ($planned.name -ne 'main-guard' -or $planned.target -ne 'branch' -or $planned.enforcement -ne 'active' -or @($planned.bypass_actors).Count -ne 0 -or (@($planned.conditions.ref_name.include) -join ',') -ne 'refs/heads/main' -or @($planned.conditions.ref_name.exclude).Count -ne 0) { throw 'hub plan guard payload is unsafe' }
      if (($types -join ',') -ne 'deletion,non_fast_forward,required_status_checks' -or ($contexts -join ',') -ne 'check' -or $status.Count -ne 1) { throw 'hub plan rules or context are incorrect' }
    }
    if ($name -eq 'verify-repo.ps1' -and $good.Out -match 'FAIL[^\r\n]*(check\.yml|required checks)') { throw 'hub verification failed good check fixture' }
    if ($name -eq 'setup-repo.ps1') {
      $nonmain = Invoke-PolicyScript $name 'hub-nonmain' 'alawein/career-engine' 'tool' 'hub-check'
      if ($nonmain.Code -eq 0 -or $nonmain.Out -notmatch 'FAIL[^\r\n]*default branch' -or $nonmain.Out -match 'DRY[^\r\n]*main-guard') { throw 'hub setup accepted non-main default branch' }
    }
    $blocked = Invoke-PolicyScript $name 'http-403' 'alawein/career-engine' 'tool' 'hub-check'
    if ($blocked.Code -ne 2 -or $blocked.Out -notmatch 'HTTP 403') { throw "$name did not stop on HTTP 403" }
    $site = Invoke-PolicyScript $name 'site' 'alawein/meshal-site' 'site' 'standard'
    if ($site.Calls -notmatch 'contents/\.github/workflows/ci\.yml') { throw "$name lost site workflow" }
    if ($name -eq 'setup-repo.ps1' -and $site.Out -notmatch 'node-ci') { throw 'site plan omitted node-ci' }
    $privateTool = Invoke-PolicyScript $name 'private-tool' 'alawein/example' 'tool' 'standard'
    if ($privateTool.Calls -notmatch 'contents/\.github/workflows/ci\.yml') { throw "$name lost private tool workflow" }
    if ($name -eq 'setup-repo.ps1' -and $privateTool.Out -match 'required_status_checks') { throw 'private tool default unexpectedly required checks' }
    $publicTool = Invoke-PolicyScript $name 'public-tool' 'alawein/example' 'tool' 'standard'
    if ($name -eq 'setup-repo.ps1' -and ($publicTool.Out -notmatch 'required_signatures' -or $publicTool.Out -notmatch 'node-ci')) { throw 'public tool plan lost signed rules or test context' }
    if ($name -eq 'verify-repo.ps1' -and ($publicTool.Out -notmatch 'PASS[^\r\n]*required_signatures' -or $publicTool.Out -notmatch 'PASS[^\r\n]*has no bypass actors')) { throw 'public rules verification lost signed or no-bypass rules' }
    $incompatible = Invoke-PolicyScript $name 'hub-good' 'alawein/meshal-site' 'site' 'hub-check'
    if ($incompatible.Code -eq 0 -or $incompatible.Calls.Trim()) { throw "$name called gh for incompatible hub policy" }
  }
  Write-Host 'PASS: fake gh script policy cases and mutation refusal'
} finally {
  $env:PATH = $savedPath
}
