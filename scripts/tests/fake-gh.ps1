$ErrorActionPreference = 'Stop'
Add-Content -LiteralPath $env:FAKE_GH_LOG -Value ($args -join ' ')
if ($args -contains '-X' -or $args -contains '--method' -or $args -contains '--input') { Write-Error 'fake gh refuses mutations'; exit 90 }
if ($args[0] -eq 'auth') { 'Logged in'; exit 0 }
if ($args[0] -ne 'api') { Write-Error 'unexpected gh command'; exit 91 }
$path = [string]$args[1]
if ($env:FAKE_GH_CASE -eq 'http-403' -and $path -eq 'repos/alawein/career-engine') { 'HTTP 403'; exit 1 }
if ($path -match '^repos/alawein/[^/]+$') {
  $visibility = if ($env:FAKE_GH_CASE -eq 'public-tool') { 'public' } else { 'private' }
  $branch = if ($env:FAKE_GH_CASE -eq 'hub-nonmain') { 'develop' } else { 'main' }
  @{ visibility=$visibility; archived=$false; default_branch=$branch; description='fixture'; allow_squash_merge=$true; allow_merge_commit=$false; allow_rebase_merge=$false; squash_merge_commit_title='PR_TITLE'; squash_merge_commit_message='BLANK'; delete_branch_on_merge=$true; allow_auto_merge=$true; has_wiki=$false; has_projects=$false; security_and_analysis=@{secret_scanning=@{status='enabled'};secret_scanning_push_protection=@{status='enabled'}} } | ConvertTo-Json -Depth 6 -Compress
  exit 0
}
if ($path -match '/contents/\.github/workflows$') {
  if ($env:FAKE_GH_CASE -eq 'hub-missing') { exit 0 }
  if ($env:FAKE_GH_CASE -like 'hub-*') { 'check.yml' } else { 'ci.yml' }
  exit 0
}
if ($path -match '/contents/\.github/workflows/(check|ci)\.yml$') {
  if ($env:FAKE_GH_CASE -in @('hub-missing', 'site-missing-ci')) { 'HTTP 404'; exit 1 }
  if ($env:FAKE_GH_CASE -eq 'hub-wrong') { "jobs:`n  wrong:`n    runs-on: ubuntu-latest" }
  elseif ($env:FAKE_GH_CASE -like 'hub-*') { "jobs:`n  check:`n    runs-on: ubuntu-latest" }
  else { "jobs:`n  markdown-lint:`n  link-check:`n  actionlint:`n  pr-title:`n  node-ci:" }
  exit 0
}
if ($path -match '/rulesets$') { "1`tmain-guard`n2`trelease-tags`n3`tmain-protection"; exit 0 }
if ($path -match '/rulesets/([123])$') {
  $id = $Matches[1]
  if ($id -eq '2') { Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../../rulesets/tags.json'); exit 0 }
  if ($id -eq '3') {
    $o = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../../rulesets/main-public.json') | ConvertFrom-Json
    if ($env:FAKE_GH_CASE -eq 'public-tool') {
      foreach ($r in $o.rules) {
        if ($r.type -eq 'required_status_checks') { $r.parameters.required_status_checks += [pscustomobject]@{context='node-ci'} }
      }
    }
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
  if ($env:FAKE_GH_CASE -like 'hub-*') {
    $o.rules += [pscustomobject]@{type='required_status_checks';parameters=@{required_status_checks=@(@{context='check'})}}
    if ($env:FAKE_GH_CASE -eq 'hub-excluded') { $o.conditions.ref_name.exclude = @('refs/heads/main') }
  }
  $o | ConvertTo-Json -Depth 12 -Compress
  exit 0
}
if ($path -match '/contents/') { 'HTTP 404'; exit 1 }
if ($path -match '/vulnerability-alerts$') { '{}'; exit 0 }
if ($path -match '/automated-security-fixes$|/private-vulnerability-reporting$') { '{"enabled":true}'; exit 0 }
if ($path -match '/actions/permissions/workflow$') { '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}'; exit 0 }
if ($path -match '/actions/permissions$') { '{"sha_pinning_required":true}'; exit 0 }
if ($path -match '/community/profile$') { '{"files":{"pull_request_template":{"url":"fixture"}}}'; exit 0 }
if ($path -match '/license$') { 'HTTP 404'; exit 1 }
if ($path -match '/topics$') { '{"names":["fixture"]}'; exit 0 }
if ($path -match '/labels\?') { exit 0 }
if ($path -match '/actions/permissions/fork-pr-contributor-approval$') { '{"approval_policy":"first_time_contributors"}'; exit 0 }
Write-Error "unexpected API: $path"
exit 92
