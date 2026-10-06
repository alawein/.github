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


# Removing opt-in forwarding, losing a language context, or silently opting in defaults fails this matrix.
foreach ($case in @(
  @{Class='profile'; Language='typescript'; Checks='markdown-lint,link-check,actionlint,pr-title'},
  @{Class='docs'; Language='typescript'; Checks='markdown-lint,link-check,actionlint,pr-title'},
  @{Class='tool'; Language='typescript'; Checks='markdown-lint,link-check,actionlint,pr-title,node-ci'},
  @{Class='tool'; Language='python'; Checks='markdown-lint,link-check,actionlint,pr-title,python-ci'},
  @{Class='lab'; Language='typescript'; Checks='markdown-lint,link-check,actionlint,pr-title,python-ci'},
  @{Class='site'; Language='typescript'; Checks='markdown-lint,link-check,actionlint,pr-title,node-ci'}
)) {
  foreach ($strict in @($false, $true)) {
    $legacy = Get-CheckPolicy -Class $case.Class -Language $case.Language -Strict:$strict
    $off = Get-CheckPolicy -Class $case.Class -Language $case.Language -Strict:$strict -RequirePrPolicy:$false
    $on = Get-CheckPolicy -Class $case.Class -Language $case.Language -Strict:$strict -RequirePrPolicy
    if (($legacy.RequiredChecks -join ',') -ne $case.Checks -or ($off.RequiredChecks -join ',') -ne $case.Checks) { throw 'legacy opt-in defaults changed' }
    if (($on.RequiredChecks -join ',') -ne ($case.Checks + ',pr-policy') -or $on.WorkflowPath -ne $legacy.WorkflowPath -or $on.RequireChecks -ne $legacy.RequireChecks) { throw 'opt-in lost class checks or changed strictness' }
  }
}
$rejected = $false
try { Get-CheckPolicy -Repo alawein/career-engine -Class tool -Language typescript -CheckProfile hub-check -RequirePrPolicy | Out-Null } catch { $rejected = $_.Exception.Message -match 'RequirePrPolicy.*hub-check' }
if (-not $rejected) { throw 'hub accepted optional policy' }
Write-Host 'PASS: optional helper preserves legacy classes and rejects hub'

$existing = '{"target":"branch","conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":[]}},"rules":[{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,"do_not_enforce_on_create":false,"required_status_checks":[{"context":"check","integration_id":42}]}}]}' | ConvertFrom-Json
$desired = '{"target":"branch","conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":[]}},"rules":[{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,"do_not_enforce_on_create":true,"required_status_checks":[{"context":"check"}]}}]}' | ConvertFrom-Json
$merged = Merge-StatusCheckRules $desired $existing
$parameters = ($merged.rules | Where-Object type -eq required_status_checks).parameters
if (-not $parameters.strict_required_status_checks_policy -or $parameters.do_not_enforce_on_create -or $parameters.required_status_checks.Count -ne 1 -or $parameters.required_status_checks[0].integration_id -ne 42) { throw 'merge weakened freshness, creation enforcement or an existing producer' }
$existing.rules[0].parameters.do_not_enforce_on_create = 'unknown'
$rejected = $false
try { Merge-StatusCheckRules $desired $existing | Out-Null } catch { $rejected = $true }
if (-not $rejected) { throw 'merge accepted an unknown enforcement boolean' }
Write-Host 'PASS: strongest status policy and malformed boolean refusal'

$ruleRoot = Join-Path $PSScriptRoot '../../rulesets'
$scopeDesired = Get-Content -LiteralPath (Join-Path $ruleRoot 'main-public.json') -Raw | ConvertFrom-Json
$scopeExisting = Get-Content -LiteralPath (Join-Path $ruleRoot 'main-public.json') -Raw | ConvertFrom-Json
$scopeExisting.conditions.ref_name.include += 'refs/heads/release/*'
$scopeMerged = Merge-StatusCheckRules $scopeDesired $scopeExisting
if (($scopeMerged.conditions.ref_name.include -join ',') -cne 'refs/heads/main,refs/heads/release/*') { throw 'setup dropped an existing protected release ref' }
$scopeExisting.conditions.ref_name.include = @('refs/heads/release/*')
$scopeDesired = Get-Content -LiteralPath (Join-Path $ruleRoot 'main-public.json') -Raw | ConvertFrom-Json
$scopeMerged = Merge-StatusCheckRules $scopeDesired $scopeExisting
if (($scopeMerged.conditions.ref_name.include -join ',') -cne 'refs/heads/release/*,refs/heads/main') { throw 'setup failed to add baseline scope while retaining an existing ref' }
foreach ($badScope in @(
  '{"target":"branch","conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":["refs/heads/release/*"]}}}',
  '{"target":"branch","conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":[]},"repository_name":{"include":["example"]}}}',
  '{"target":"branch","conditions":{"ref_name":{"include":"refs/heads/main","exclude":[]}}}',
  '{"target":"branch","conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":null}}}',
  '{"target":"branch","conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":[],"unknown":true}}}',
  '{"target":"branch","conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}}}',
  '{"target":"branch","conditions":{"ref_name":{"include":["~ALL"],"exclude":[]}}}',
  '{"target":"branch","conditions":{"ref_name":{"include":["refs/tags/v*"],"exclude":[]}}}',
  '{"target":"tag","conditions":{"ref_name":{"include":["refs/tags/v*"],"exclude":[]}}}'
)) {
  $rejected = $false
  try { Get-RulesetRefScope ($badScope | ConvertFrom-Json) -ExpectedTarget branch | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { throw "accepted an incompatible or malformed scope: $badScope" }
}
Write-Host 'PASS: existing additional protected refs retained'

$parameterDesired = Get-Content -LiteralPath (Join-Path $ruleRoot 'main-public.json') -Raw | ConvertFrom-Json
$parameterExisting = Get-Content -LiteralPath (Join-Path $ruleRoot 'main-public.json') -Raw | ConvertFrom-Json
($parameterDesired.rules | Where-Object type -eq pull_request).parameters.required_approving_review_count = 2
$existingPrParameters = ($parameterExisting.rules | Where-Object type -eq pull_request).parameters
$existingPrParameters.allowed_merge_methods = @('merge', 'squash')
$existingPrParameters.require_code_owner_review = $true
$parameterMerged = Merge-StatusCheckRules $parameterDesired $parameterExisting
$mergedPrParameters = ($parameterMerged.rules | Where-Object type -eq pull_request).parameters
if ($mergedPrParameters.required_approving_review_count -ne 2 -or ($mergedPrParameters.allowed_merge_methods -join ',') -cne 'squash' -or -not $mergedPrParameters.require_code_owner_review) { throw 'merge kept weaker existing pull-request parameters instead of satisfying the baseline' }
$existingPrParameters.required_approving_review_count = 4
$parameterMerged = Merge-StatusCheckRules $parameterDesired $parameterExisting
if (($parameterMerged.rules | Where-Object type -eq pull_request).parameters.required_approving_review_count -ne 4) { throw 'merge lowered a stronger existing approval count' }
($parameterDesired.rules | Where-Object type -eq pull_request).parameters | Add-Member future_strength 2
$existingPrParameters | Add-Member future_strength 1
$rejected = $false
try { Merge-StatusCheckRules $parameterDesired $parameterExisting | Out-Null } catch { $rejected = $_.Exception.Message -match 'cannot determine protection strength' }
if (-not $rejected) { throw 'merge guessed at unknown parameter strength' }
$rejected = $false
try { Merge-RuleParameters $null ('{"type":"pull_request","parameters":{}}' | ConvertFrom-Json) | Out-Null } catch { $rejected = $_.Exception.Message -match 'missing.*parameter' }
if (-not $rejected) { throw 'merge retained an unreadable extra pull-request rule' }
Write-Host 'PASS: stronger baseline and existing pull-request protections retained'

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
function Invoke-PolicyScript([string]$Name, [string]$Case, [string]$Repo, [string]$Class, [string]$Profile, [switch]$Strict, [switch]$RequirePrPolicy, [string]$Language = 'typescript') {
  $env:FAKE_GH_CASE = $Case
  $env:FAKE_GH_CLASS = $Class
  $env:FAKE_GH_LANGUAGE = $Language
  Set-Content -LiteralPath $env:FAKE_GH_LOG -Value ''
  # Load the same fake in the child process instead of starting a PowerShell
  # process for every API request. Each production script still runs isolated.
  $quotedFixture = (Join-Path $PSScriptRoot 'fake-gh.ps1').Replace("'", "''")
  $quotedScript = (Join-Path $scripts $Name).Replace("'", "''")
  $scriptArgs = @{ Repo=$Repo; Language=$Language; CheckProfile=$Profile }
  if ($Class) { $scriptArgs.Class = $Class }
  if ($Strict) { $scriptArgs.Strict = $true }
  if ($RequirePrPolicy) { $scriptArgs.RequirePrPolicy = $true }
  $quotedArgs = @($scriptArgs.Keys | ForEach-Object {
    $value = $scriptArgs[$_]
    if ($value -is [bool]) { "$_=`$true" } else { "$_='" + $value.Replace("'", "''") + "'" }
  }) -join ';'
  $bootstrap = ". '$quotedFixture'; function global:gh { Invoke-FakeGh @args }; `$scriptArgs=@{$quotedArgs}; & '$quotedScript' @scriptArgs; exit `$LASTEXITCODE"
  $output = (& $pwshPath -NoProfile -Command $bootstrap 2>&1 | Out-String)
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

  $originalRules = @{}
  foreach ($file in @('main-public.json', 'main-private.json', 'main-site.json')) { $originalRules[$file] = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $ruleRoot $file))) }
  foreach ($name in @('setup-repo.ps1', 'verify-repo.ps1')) {
    $hubOpt = Invoke-PolicyScript $name hub-good alawein/career-engine tool hub-check -RequirePrPolicy
    if ($hubOpt.Code -ne 2 -or $hubOpt.Calls.Trim() -or $hubOpt.Out -notmatch 'RequirePrPolicy.*hub-check') { throw "$name did not reject hub opt-in before gh" }
    $nonstrict = Invoke-PolicyScript $name policy-private-ready alawein/example docs standard -RequirePrPolicy
    if ($nonstrict.Code -ne 2 -or $nonstrict.Out -notmatch 'RequirePrPolicy.*Strict' -or $nonstrict.Calls -match '/rulesets') { throw "$name silently accepted private non-strict opt-in" }
    foreach ($case in @(
      @{Class='docs'; Language='typescript'; Visibility='public'; Checks='markdown-lint,link-check,actionlint,pr-title,pr-policy'; Template='main-public.json'},
      @{Class='tool'; Language='typescript'; Visibility='public'; Checks='markdown-lint,link-check,actionlint,pr-title,node-ci,pr-policy'; Template='main-public.json'},
      @{Class='tool'; Language='python'; Visibility='public'; Checks='markdown-lint,link-check,actionlint,pr-title,python-ci,pr-policy'; Template='main-public.json'},
      @{Class='docs'; Language='typescript'; Visibility='private'; Checks='markdown-lint,link-check,actionlint,pr-title,pr-policy'},
      @{Class='tool'; Language='python'; Visibility='private'; Checks='markdown-lint,link-check,actionlint,pr-title,python-ci,pr-policy'},
      @{Class='site'; Language='typescript'; Visibility='private'; Checks='markdown-lint,link-check,actionlint,pr-title,node-ci,pr-policy'; Template='main-site.json'}
    )) {
      $strict = $case.Visibility -eq 'private' -and $case.Class -ne 'site'
      $ready = Invoke-PolicyScript $name "policy-$($case.Visibility)-ready" alawein/example $case.Class standard -Language $case.Language -Strict:$strict -RequirePrPolicy
      if ($name -eq 'verify-repo.ps1') {
        if ($ready.Out -match 'FAIL[^\r\n]*(required checks|ci\.yml with)' -or $ready.Out -notmatch 'PASS[^\r\n]*required checks') { throw "$name rejected ready opt-in $($case.Class): $($ready.Out)" }
      } else {
        if ($ready.Code -ne 0 -or $ready.Out -notmatch '(?m)^DRY\s+gh api -X (?:PUT|POST) repos/alawein/example/rulesets(?:/[13])? --input -\s+<-\s+(.+)$') { throw "missing opt-in payload: $($ready.Out)" }
        $planned = $Matches[1] | ConvertFrom-Json
        $status = @($planned.rules | Where-Object type -eq required_status_checks)
        $contexts = @($status[0].parameters.required_status_checks | ForEach-Object context)
        if ($status.Count -ne 1 -or ($contexts -join ',') -ne $case.Checks) { throw "opt-in payload lost complete contexts: $($contexts -join ',')" }
        if ($case.Template) {
          $expected = Get-Content -LiteralPath (Join-Path $ruleRoot $case.Template) -Raw | ConvertFrom-Json
          ($expected.rules | Where-Object type -eq required_status_checks).parameters.required_status_checks = @($case.Checks -split ',' | ForEach-Object { [pscustomobject]@{context=$_} })
          if (($planned | ConvertTo-Json -Depth 12 -Compress) -cne ($expected | ConvertTo-Json -Depth 12 -Compress)) { throw 'opt-in modified unrelated template policy' }
        }
      }
      foreach ($bad in @('missing-gate', 'placeholder')) {
        $incomplete = Invoke-PolicyScript $name "policy-$($case.Visibility)-$bad" alawein/example $case.Class standard -Language $case.Language -Strict:$strict -RequirePrPolicy
        if ($incomplete.Code -eq 0 -or ($name -eq 'setup-repo.ps1' -and $incomplete.Out -match 'DRY[^\r\n]*required_status_checks')) { throw "$name accepted $bad opt-in" }
      }
      if ($name -eq 'verify-repo.ps1') {
        $wrong = Invoke-PolicyScript $name "policy-$($case.Visibility)-wrong-context" alawein/example $case.Class standard -Language $case.Language -Strict:$strict -RequirePrPolicy
        if ($wrong.Out -notmatch 'FAIL[^\r\n]*required checks') { throw 'opt-in accepted wrong rules contexts' }
      }
    }
  }
  $omitted = Invoke-PolicyScript verify-repo.ps1 policy-public-extra-context alawein/example '' standard -RequirePrPolicy
  if ($omitted.Out -notmatch 'PASS[^\r\n]*required checks') { throw 'omitted class rejected additional unknown language context' }
  $missingPolicy = Invoke-PolicyScript verify-repo.ps1 policy-public-missing-context alawein/example '' standard -RequirePrPolicy
  if ($missingPolicy.Out -notmatch 'FAIL[^\r\n]*required checks') { throw 'omitted class accepted missing policy context' }
  $legacySubset = Invoke-PolicyScript verify-repo.ps1 policy-public-missing-context alawein/example '' standard
  if ($legacySubset.Out -notmatch 'PASS[^\r\n]*required checks') { throw 'legacy unknown-class subset changed' }
  foreach ($file in $originalRules.Keys) { if ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $ruleRoot $file))) -cne $originalRules[$file]) { throw 'setup mutated checked-in ruleset JSON' } }
  Write-Host 'PASS: opt-in dry-run payloads, private strictness, readiness and omitted-class rules'

  $extraChecks = Invoke-PolicyScript verify-repo.ps1 checks-extra-bound alawein/example tool standard
  if ($extraChecks.Code -ne 0 -or $extraChecks.Out -notmatch 'PASS[^\r\n]*required checks[^\r\n]*browser-tests') { throw "baseline plus extra bound checks failed verification: $($extraChecks.Out)" }
  foreach ($excludedScope in @('checks-scope-exclude-main', 'checks-scope-exclude-all')) {
    $excluded = Invoke-PolicyScript verify-repo.ps1 $excludedScope alawein/example tool standard
    if ($excluded.Code -ne 1 -or $excluded.Out -notmatch 'FAIL[^\r\n]*main-protection ref') { throw "verification accepted an excluded protected main: $($excluded.Out)" }
  }
  $missingCheck = Invoke-PolicyScript verify-repo.ps1 checks-missing-baseline alawein/example tool standard
  if ($missingCheck.Code -ne 1 -or $missingCheck.Out -notmatch 'FAIL[^\r\n]*required checks') { throw 'missing baseline passed verification' }
  $preserve = Invoke-PolicyScript setup-repo.ps1 checks-extra-bound alawein/example tool standard
  if ($preserve.Code -ne 0 -or $preserve.Out -notmatch '(?m)^DRY\s+gh api -X PUT repos/alawein/example/rulesets/3 --input -\s+<-\s+(.+)$') { throw "missing preservation plan: $($preserve.Out)" }
  $firstPlan = $Matches[1]
  $planned = $firstPlan | ConvertFrom-Json
  $status = $planned.rules | Where-Object type -eq required_status_checks
  $checks = @($status.parameters.required_status_checks)
  if ($checks.Count -ne 7 -or @($checks | Where-Object { $_.context -ne 'browser-tests' -and $_.integration_id -ne 15368 }).Count -or @($checks | Where-Object { $_.context -eq 'browser-tests' -and $_.integration_id -in @(99,100) }).Count -ne 2 -or -not $status.parameters.strict_required_status_checks_policy) { throw 'setup weakened additional checks, producer bindings or strictness' }
  if (($planned.conditions.ref_name.include -join ',') -cne 'refs/heads/main,refs/heads/release/*' -or @($planned.conditions.ref_name.exclude).Count -ne 0) { throw 'setup weakened existing protected ref scope' }
  $parameterPlan = Invoke-PolicyScript setup-repo.ps1 checks-pr-weak alawein/example tool standard
  if ($parameterPlan.Code -ne 0 -or $parameterPlan.Out -notmatch '(?m)^DRY\s+gh api -X PUT repos/alawein/example/rulesets/3 --input -\s+<-\s+(.+)$') { throw "missing parameter preservation plan: $($parameterPlan.Out)" }
  $plannedParameters = (($Matches[1] | ConvertFrom-Json).rules | Where-Object type -eq pull_request).parameters
  if (($plannedParameters.allowed_merge_methods -join ',') -cne 'squash' -or $plannedParameters.required_approving_review_count -ne 2 -or -not $plannedParameters.require_code_owner_review -or -not $plannedParameters.require_extra_approval_for_unattributed_changes) { throw 'setup did not enforce the baseline while retaining stronger existing PR parameters' }
  $env:FAKE_GH_RULESET = Join-Path $env:TEMP 'kit-check-policy-ruleset.json'
  try {
    Set-Content -LiteralPath $env:FAKE_GH_RULESET -Value $firstPlan
    $repeat = Invoke-PolicyScript setup-repo.ps1 checks-extra-bound alawein/example tool standard
    if ($repeat.Code -ne 0 -or $repeat.Out -notmatch '(?m)^DRY\s+gh api -X PUT repos/alawein/example/rulesets/3 --input -\s+<-\s+(.+)$' -or $Matches[1] -cne $firstPlan) { throw 'repeated setup changed the preserved ruleset' }
  } finally { Remove-Item Env:FAKE_GH_RULESET -ErrorAction SilentlyContinue }
  foreach ($bad in @('checks-list-unavailable', 'checks-list-malformed', 'checks-list-empty-object', 'checks-detail-unavailable', 'checks-detail-malformed', 'checks-detail-bad-json', 'checks-binding-malformed', 'checks-scope-excluded', 'checks-scope-exclude-main', 'checks-scope-exclude-all', 'checks-scope-unsupported', 'checks-scope-malformed', 'checks-scope-target', 'checks-pr-count-malformed', 'checks-pr-flag-malformed', 'checks-pr-incompatible')) {
    $unreadable = Invoke-PolicyScript setup-repo.ps1 $bad alawein/example tool standard
    if ($unreadable.Code -ne 2 -or $unreadable.Out -notmatch 'STOP' -or $unreadable.Out -match '(?m)^DRY\s+gh api -X') { throw "unreadable existing rulesets allowed a write plan: $bad $($unreadable.Out)" }
  }
  Write-Host 'PASS: extra checks, bindings and refs retained, missing baseline fails, unreadable preflight stops, repeated setup stable'
  $bound = [pscustomobject]@{context='browser-tests';integration_id=99}
  if (-not (Test-StatusCheckRequirement $bound @($bound)) -or (Test-StatusCheckRequirement $bound @([pscustomobject]@{context='browser-tests';integration_id=100})) -or (Test-StatusCheckRequirement $bound @([pscustomobject]@{context='browser-tests'})) -or (Test-StatusCheckRequirement $bound @([pscustomobject]@{context='Browser-tests';integration_id=99}))) { throw 'producer comparison accepted the wrong producer, unbound check or changed context' }
  if (-not (Test-StatusCheckRequirement ([pscustomobject]@{context='browser-tests'}) @($bound))) { throw 'an unbound baseline rejected a stronger producer binding' }
  Write-Host 'PASS: producer equality and stronger bound-baseline comparison'

  Write-Host 'PASS: fake gh script policy cases and mutation refusal'
} finally {
  $env:PATH = $savedPath
}
