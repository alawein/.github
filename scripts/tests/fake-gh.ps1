function Invoke-FakeGh {
$ErrorActionPreference = 'Stop'
Add-Content -LiteralPath $env:FAKE_GH_LOG -Value ($args -join ' ')
if ($args -contains '-X' -or $args -contains '--method' -or $args -contains '--input') { Write-Error 'fake gh refuses mutations'; $global:LASTEXITCODE = 90; return }
if ($args[0] -eq 'auth') { 'Logged in'; $global:LASTEXITCODE = 0; return }
if ($args[0] -ne 'api') { Write-Error 'unexpected gh command'; $global:LASTEXITCODE = 91; return }
$path = [string]$args[1]
if ($env:FAKE_GH_CASE -eq 'http-403' -and $path -eq 'repos/alawein/career-engine') { 'HTTP 403'; $global:LASTEXITCODE = 1; return }
if ($path -match '^repos/alawein/[^/]+$') {
  $visibility = if (($env:FAKE_GH_CASE -eq 'public-tool' -or $env:FAKE_GH_CASE -like 'policy-public-*' -or $env:FAKE_GH_CASE -like 'checks-*')) { 'public' } else { 'private' }
  $branch = if ($env:FAKE_GH_CASE -eq 'hub-nonmain') { 'develop' } else { 'main' }
  @{ visibility=$visibility; archived=$false; default_branch=$branch; description='fixture'; allow_squash_merge=$true; allow_merge_commit=$false; allow_rebase_merge=$false; squash_merge_commit_title='PR_TITLE'; squash_merge_commit_message='BLANK'; delete_branch_on_merge=$true; allow_auto_merge=$true; has_wiki=$false; has_projects=$false; security_and_analysis=@{secret_scanning=@{status='enabled'};secret_scanning_push_protection=@{status='enabled'}} } | ConvertTo-Json -Depth 6 -Compress
  $global:LASTEXITCODE = 0; return
}
if ($path -match '/contents/\.github/workflows$') {
  if ($env:FAKE_GH_CASE -eq 'hub-missing') { $global:LASTEXITCODE = 0; return }
  if ($env:FAKE_GH_CASE -like 'hub-*') { 'check.yml' } else { 'ci.yml' }
  $global:LASTEXITCODE = 0; return
}
if ($path -match '/contents/\.github/workflows/(check|ci)\.yml$') {
  if ($env:FAKE_GH_CASE -in @('hub-missing', 'site-missing-ci')) { 'HTTP 404'; $global:LASTEXITCODE = 1; return }
  if ($env:FAKE_GH_CASE -like 'policy-*') {
    $jobs = @('markdown-lint', 'link-check', 'actionlint', 'pr-title')
    if ($env:FAKE_GH_CLASS -eq 'site' -or ($env:FAKE_GH_CLASS -eq 'tool' -and $env:FAKE_GH_LANGUAGE -eq 'typescript')) { $jobs += 'node-ci' }
    if ($env:FAKE_GH_CLASS -eq 'lab' -or ($env:FAKE_GH_CLASS -eq 'tool' -and $env:FAKE_GH_LANGUAGE -eq 'python')) { $jobs += 'python-ci' }
    if ($env:FAKE_GH_CASE -notlike '*missing-gate') { $jobs += 'pr-policy' }
    'jobs:'
    foreach ($job in $jobs) { "  ${job}:" }
    if ($env:FAKE_GH_CASE -like '*placeholder') { '    uses: alawein/.github/.github/workflows/pr-policy.yml@0000000000000000000000000000000000000000' }
  }
  elseif ($env:FAKE_GH_CASE -eq 'hub-wrong') { "jobs:`n  wrong:`n    runs-on: ubuntu-latest" }
  elseif ($env:FAKE_GH_CASE -like 'hub-*') { "jobs:`n  check:`n    runs-on: ubuntu-latest" }
  else { "jobs:`n  markdown-lint:`n  link-check:`n  actionlint:`n  pr-title:`n  node-ci:" }
  $global:LASTEXITCODE = 0; return
}
if ($path -match '/rulesets$') {
  if ($env:FAKE_GH_CASE -eq 'checks-list-unavailable') { 'HTTP 404'; $global:LASTEXITCODE = 1; return }
  if ($env:FAKE_GH_CASE -eq 'checks-list-malformed') { 'not a ruleset list'; $global:LASTEXITCODE = 0; return }
  if ($env:FAKE_GH_CASE -eq 'checks-list-empty-object') { '{}'; $global:LASTEXITCODE = 0; return }
  if ($args -contains '--slurp') { '[[{"id":1,"name":"main-guard"},{"id":2,"name":"release-tags"},{"id":3,"name":"main-protection"}]]'; $global:LASTEXITCODE = 0; return }
  "1`tmain-guard`n2`trelease-tags`n3`tmain-protection"; $global:LASTEXITCODE = 0; return
}
if ($path -match '/rulesets/([123])$') {
  $id = $Matches[1]
  if ($id -eq '2') { Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../../rulesets/tags.json'); $global:LASTEXITCODE = 0; return }
  if ($id -eq '3') {
    if ($env:FAKE_GH_CASE -eq 'checks-detail-unavailable') { 'HTTP 404'; $global:LASTEXITCODE = 1; return }
    if ($env:FAKE_GH_CASE -eq 'checks-detail-malformed') { '{"name":"main-protection"}'; $global:LASTEXITCODE = 0; return }
    if ($env:FAKE_GH_CASE -eq 'checks-detail-bad-json') { '{invalid'; $global:LASTEXITCODE = 0; return }
    if ($env:FAKE_GH_RULESET -and $env:FAKE_GH_CASE -eq 'checks-extra-bound') { Get-Content -LiteralPath $env:FAKE_GH_RULESET -Raw; $global:LASTEXITCODE = 0; return }
    $o = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../../rulesets/main-public.json') | ConvertFrom-Json
    if ($env:FAKE_GH_CASE -eq 'public-tool' -or $env:FAKE_GH_CASE -like 'checks-*') {
      foreach ($r in $o.rules) {
        if ($r.type -eq 'required_status_checks') { $r.parameters.required_status_checks += [pscustomobject]@{context='node-ci'} }
      }
    }
    if ($env:FAKE_GH_CASE -in @('checks-extra-bound', 'checks-missing-baseline', 'checks-binding-malformed')) {
      $o.conditions.ref_name.include += 'refs/heads/release/*'
      $status = $o.rules | Where-Object type -eq required_status_checks
      foreach ($check in $status.parameters.required_status_checks) { $check | Add-Member integration_id 15368 }
      $status.parameters.required_status_checks += @([pscustomobject]@{context='browser-tests';integration_id=99}, [pscustomobject]@{context='browser-tests';integration_id=100})
      $status.parameters.strict_required_status_checks_policy = $true
      if ($env:FAKE_GH_CASE -eq 'checks-missing-baseline') { $status.parameters.required_status_checks = @($status.parameters.required_status_checks | Where-Object context -ne node-ci) }
      if ($env:FAKE_GH_CASE -eq 'checks-binding-malformed') { $status.parameters.required_status_checks[0].integration_id = 'unknown' }
    }
    if ($env:FAKE_GH_CASE -eq 'checks-scope-excluded') { $o.conditions.ref_name.exclude = @('refs/heads/release/*') }
    if ($env:FAKE_GH_CASE -eq 'checks-scope-exclude-main') { $o.conditions.ref_name.exclude = @('refs/heads/main') }
    if ($env:FAKE_GH_CASE -eq 'checks-scope-exclude-all') { $o.conditions.ref_name.exclude = @('~ALL') }
    if ($env:FAKE_GH_CASE -eq 'checks-scope-unsupported') { $o.conditions | Add-Member repository_name ([pscustomobject]@{include=@('example')}) }
    if ($env:FAKE_GH_CASE -eq 'checks-scope-malformed') { $o.conditions.ref_name.include = 'refs/heads/main' }
    if ($env:FAKE_GH_CASE -eq 'checks-scope-target') { $o.target = 'tag' }
    $prParameters = ($o.rules | Where-Object type -eq pull_request).parameters
    if ($env:FAKE_GH_CASE -eq 'checks-pr-weak') {
      $prParameters.allowed_merge_methods = @('merge', 'squash')
      $prParameters.required_approving_review_count = 2
      $prParameters.require_code_owner_review = $true
      $prParameters | Add-Member require_extra_approval_for_unattributed_changes $true
    }
    if ($env:FAKE_GH_CASE -eq 'checks-pr-count-malformed') { $prParameters.required_approving_review_count = 'unknown' }
    if ($env:FAKE_GH_CASE -eq 'checks-pr-flag-malformed') { $prParameters.require_code_owner_review = 'unknown' }
    if ($env:FAKE_GH_CASE -eq 'checks-pr-incompatible') { $prParameters.allowed_merge_methods = @('merge') }
  }
  else {
    $ruleFile = if ($env:FAKE_GH_CASE -in @('site-ready', 'site-wrong')) { 'main-site.json' } else { 'main-private.json' }
    $o = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot "../../rulesets/$ruleFile") | ConvertFrom-Json
    if ($env:FAKE_GH_CASE -eq 'site-wrong') {
      foreach ($r in $o.rules) {
        if ($r.type -eq 'required_status_checks') { $r.parameters.required_status_checks[-1].context = 'wrong-ci' }
      }
    }
  }
  if ($env:FAKE_GH_CASE -like 'policy-*') {
    if ($id -eq '1') { $o = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../../rulesets/main-site.json') | ConvertFrom-Json }
    $checks = @('markdown-lint', 'link-check', 'actionlint', 'pr-title')
    if ($env:FAKE_GH_CLASS -eq 'site' -or ($env:FAKE_GH_CLASS -eq 'tool' -and $env:FAKE_GH_LANGUAGE -eq 'typescript')) { $checks += 'node-ci' }
    if ($env:FAKE_GH_CLASS -eq 'lab' -or ($env:FAKE_GH_CLASS -eq 'tool' -and $env:FAKE_GH_LANGUAGE -eq 'python')) { $checks += 'python-ci' }
    if ($env:FAKE_GH_CASE -notlike '*missing-context') { $checks += 'pr-policy' }
    if ($env:FAKE_GH_CASE -like '*extra-context') { $checks += 'unknown-language-ci' }
    if ($env:FAKE_GH_CASE -like '*wrong-context') { $checks[-1] = 'wrong-policy' }
    ($o.rules | Where-Object type -eq required_status_checks).parameters.required_status_checks = @($checks | ForEach-Object { [pscustomobject]@{context=$_} })
  }
  if ($env:FAKE_GH_CASE -like 'hub-*' -and $id -eq '1') {
    $o.rules += [pscustomobject]@{type='required_status_checks';parameters=@{required_status_checks=@(@{context='check'})}}
    if ($env:FAKE_GH_CASE -eq 'hub-excluded') { $o.conditions.ref_name.exclude = @('refs/heads/main') }
  }
  $o | ConvertTo-Json -Depth 12 -Compress
  $global:LASTEXITCODE = 0; return
}
if ($env:FAKE_GH_CASE -like 'labels-*' -and $path -match '/contents/(README\.md|\.github/dependabot\.yml)$') { $Matches[1]; $global:LASTEXITCODE = 0; return }
if ($env:FAKE_GH_CASE -like 'checks-*' -and $path -match '/contents/(README\.md|\.github/dependabot\.yml|\.github/CODEOWNERS|SECURITY\.md)$') { $Matches[1]; $global:LASTEXITCODE = 0; return }
if ($path -match '/contents/') { 'HTTP 404'; $global:LASTEXITCODE = 1; return }
if ($path -match '/vulnerability-alerts$') { '{}'; $global:LASTEXITCODE = 0; return }
if ($path -match '/automated-security-fixes$|/private-vulnerability-reporting$') { '{"enabled":true}'; $global:LASTEXITCODE = 0; return }
if ($path -match '/actions/permissions/workflow$') { '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}'; $global:LASTEXITCODE = 0; return }
if ($path -match '/actions/permissions$') { '{"sha_pinning_required":true}'; $global:LASTEXITCODE = 0; return }
if ($path -match '/community/profile$') { '{"files":{"pull_request_template":{"url":"fixture"}}}'; $global:LASTEXITCODE = 0; return }
if ($path -match '/license$') { if ($env:FAKE_GH_CASE -like 'checks-*') { '{"license":{"spdx_id":"MIT"}}'; $global:LASTEXITCODE = 0; return }; 'HTTP 404'; $global:LASTEXITCODE = 1; return }
if ($path -match '/topics$') { '{"names":["fixture"]}'; $global:LASTEXITCODE = 0; return }
if ($path -match '/labels\?') {
  if ($env:FAKE_GH_CASE -like 'labels-*' -or $env:FAKE_GH_CASE -like 'checks-*') {
    "feat`ta2eeef`tNew feature or capability"
    if ($env:FAKE_GH_CASE -ne 'labels-missing') {
      $color = if ($env:FAKE_GH_CASE -eq 'labels-color') { 'ffffff' } else { 'd73a4a' }
      $description = if ($env:FAKE_GH_CASE -eq 'labels-description') { 'Bug fix or Correction' } else { 'Bug fix or correction' }
      "fix`t$color`t$description"
    }
    "docs`t0075ca`tDocumentation only change"
    "chore`tcfd3d7`tMaintenance, tooling, or cleanup with no behavior change"
    "blocked`tb60205`tCannot proceed until an external dependency or decision is resolved"
    if ($env:FAKE_GH_CASE -like 'labels-*') {
      "dependencies`t0366d6`tDependency updates"
      "accessibility`t7057ff`tAccessibility improvements"
      "javascript`t168700`tJavaScript changes"
    }
  }
  $global:LASTEXITCODE = 0; return
}
if ($path -match '/actions/permissions/fork-pr-contributor-approval$') { '{"approval_policy":"first_time_contributors"}'; $global:LASTEXITCODE = 0; return }
Write-Error "unexpected API: $path"
$global:LASTEXITCODE = 92; return

}
if ($MyInvocation.InvocationName -ne '.') { Invoke-FakeGh @args; exit $LASTEXITCODE }
