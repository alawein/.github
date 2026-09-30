<#
.SYNOPSIS
  Read-only audit of one repo against the alawein standard.

.DESCRIPTION
  Makes GET calls only. Prints PASS or FAIL per line (NOTE for things that
  do not apply). Exit code is 0 when there are no FAIL lines, 1 otherwise.
  A read that fails with anything but 404 (403, 429, 5xx) stops the audit, exit 2.
  Checks: default branch, merge settings, wiki and projects, Dependabot,
  secret scanning and private vulnerability reporting (public only), Actions token, branch ruleset, tag ruleset,
  required check names, labels, topics, license file, community files.

.PARAMETER Repo
  owner/name, for example alawein/example-app.

.PARAMETER Class
  Repo class: profile, docs, tool, site, or lab (docs\system\repos.md). Omit it
  when unknown: the license, issue, and test-check lines then print NOTE
  instead of PASS or FAIL.

.PARAMETER Language
  typescript (default) or python. A tool uses it to pick its test check
  (node-ci or python-ci). A site uses node-ci and a lab uses python-ci.

.PARAMETER Strict
  Private repos: also expect pull request and linear history in the ruleset.
  Class site implies it.

.EXAMPLE
  .\verify-repo.ps1 -Repo alawein/example-app -Class tool -Language python
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [ValidateSet('', 'profile', 'docs', 'tool', 'site', 'lab')][string]$Class = '',
  [ValidateSet('typescript', 'python')][string]$Language = 'typescript',
  [switch]$Strict
)

$ErrorActionPreference = 'Continue'
# The environment token can be stale and shadow the gh keyring login.
Remove-Item Env:GITHUB_TOKEN, Env:GH_TOKEN -ErrorAction SilentlyContinue

# Use gh.exe explicitly: an extensionless gh shim can sit earlier on PATH.
$GhCmd = Get-Command gh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$Gh = 'gh'
if ($GhCmd) { $Gh = $GhCmd.Source }

$KitRoot = Split-Path -Parent $PSScriptRoot
$BaseChecks = @('markdown-lint', 'link-check', 'actionlint', 'pr-title')
# The test check a repo with code must also require. Empty for profile, docs, or an unknown class.
$TestCheck = ''
switch ($Class) {
  'site' { $TestCheck = 'node-ci' }
  'lab'  { $TestCheck = 'python-ci' }
  'tool' { if ($Language -eq 'python') { $TestCheck = 'python-ci' } else { $TestCheck = 'node-ci' } }
}
$RequiredChecks = @($BaseChecks)
if ($TestCheck) { $RequiredChecks += $TestCheck }
$script:Pass = 0
$script:Fail = 0

function Add-Result([string]$Name, [bool]$Ok, [string]$Detail) {
  if ($Ok) { $script:Pass++; $tag = 'PASS' } else { $script:Fail++; $tag = 'FAIL' }
  Write-Host ('{0}  {1}: {2}' -f $tag, $Name, $Detail)
}
function Add-Note([string]$Name, [string]$Detail) { Write-Host ('NOTE  {0}: {1}' -f $Name, $Detail) }

# A read may fail only with 404 (not there). Any other failure (403, 429, 5xx, network) stops
# the audit: a failed read is not evidence that something is missing.
function Stop-OnReadError([string]$Text, [int]$Code) {
  if ($Code -eq 0) { return }
  $http = ''
  if ($Text -match 'HTTP (\d{3})') { $http = $Matches[1] }
  if ($http -eq '404') { return }
  Write-Host ('STOP: read failed (exit {0}, HTTP {1}): {2}' -f $Code, $http, $Text.Substring(0, [Math]::Min(300, $Text.Length)))
  if ($Text -match 'Upgrade to GitHub Pro') { Write-Host 'See docs\system\repos.md, section "Private repo limits and fallback".' }
  exit 2
}

# GET only. Returns Code, Out, and Json when the body parses.
function Get-Api([string[]]$GhArgs) {
  $text = (& $Gh api @GhArgs 2>&1 | Out-String).Trim()
  $code = $LASTEXITCODE
  Stop-OnReadError $text $code
  $json = $null
  if ($code -eq 0 -and ($text.StartsWith('{') -or $text.StartsWith('['))) {
    try { $json = $text | ConvertFrom-Json } catch { $json = $null }
  }
  return [pscustomobject]@{ Code = $code; Out = $text; Json = $json }
}

function Read-LabelNames([string]$Path) {
  $items = New-Object System.Collections.ArrayList
  $cur = $null
  foreach ($line in (Get-Content -LiteralPath $Path)) {
    if ($line -match '^\s*#' -or $line.Trim() -eq '') { continue }
    if ($line -match '^-\s+name:\s*"?([^"]+?)"?\s*$') {
      if ($cur) { [void]$items.Add($cur) }
      $cur = [pscustomobject]@{ Name = $Matches[1]; Color = ''; Description = ''; Aliases = @() }
    }
    elseif ($cur -and $line -match '^\s+color:\s*"?([0-9a-fA-F]{6})"?\s*$') { $cur.Color = $Matches[1].ToLower() }
    elseif ($cur -and $line -match '^\s+description:\s*"(.*)"\s*$') { $cur.Description = $Matches[1] }
    elseif ($cur -and $line -match '^\s+aliases:\s*\[(.*)\]\s*$') {
      $cur.Aliases = @($Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim('"') } | Where-Object { $_ })
    }
  }
  if ($cur) { [void]$items.Add($cur) }
  return $items
}

function Test-Path-Api([string]$Path) {
  $t = (& $Gh api "repos/$Repo/contents/$Path" --jq '.name' 2>&1 | Out-String).Trim()
  $c = $LASTEXITCODE
  Stop-OnReadError $t $c
  return ($c -eq 0)
}

# ---------- repo ----------

if ($Repo -notmatch '^[^/]+/[^/]+$') { Write-Host 'STOP: -Repo must look like alawein/name'; exit 2 }
if ($Repo -cmatch '^[^/]+/ARCHIVE-') { Write-Host 'STOP: ARCHIVE- repos are retired and are not audited here. Use scripts\audit-archive.ps1.'; exit 2 }
$classText = $Class
if (-not $classText) { $classText = 'unknown' }
Write-Host "Audit of $Repo (class $classText), read-only"
Write-Host ''

$auth = (& $Gh auth status 2>&1 | Out-String)
if ($auth -notmatch 'Logged in') { Write-Host 'STOP: gh is not logged in (run gh auth login)'; exit 2 }

$r = Get-Api @("repos/$Repo")
if ($r.Code -ne 0 -or -not $r.Json) { Write-Host "STOP: cannot read $Repo"; Write-Host $r.Out; exit 2 }
$i = $r.Json
$isPublic = ($i.visibility -eq 'public')
$useStrict = ([bool]$Strict) -or ($Class -eq 'site')

Add-Result 'repo not archived' (-not $i.archived) ("archived=" + $i.archived)
Add-Result 'default branch' ($i.default_branch -eq 'main') ("default_branch=" + $i.default_branch + ", want main")
Add-Result 'description' ([bool]$i.description) ("length " + ([string]$i.description).Length)
Add-Result 'squash merge on' ($i.allow_squash_merge -eq $true) ("allow_squash_merge=" + $i.allow_squash_merge)
Add-Result 'merge commits off' ($i.allow_merge_commit -eq $false) ("allow_merge_commit=" + $i.allow_merge_commit)
Add-Result 'rebase merge off' ($i.allow_rebase_merge -eq $false) ("allow_rebase_merge=" + $i.allow_rebase_merge)
Add-Result 'squash title is PR_TITLE' ($i.squash_merge_commit_title -eq 'PR_TITLE') ("squash_merge_commit_title=" + $i.squash_merge_commit_title)
Add-Result 'squash message is blank' ($i.squash_merge_commit_message -eq 'BLANK') ("squash_merge_commit_message=" + $i.squash_merge_commit_message)
Add-Result 'delete branch on merge' ($i.delete_branch_on_merge -eq $true) ("delete_branch_on_merge=" + $i.delete_branch_on_merge)
Add-Result 'auto-merge allowed' ($i.allow_auto_merge -eq $true) ("allow_auto_merge=" + $i.allow_auto_merge)
Add-Result 'wiki off' ($i.has_wiki -eq $false) ("has_wiki=" + $i.has_wiki)
Add-Result 'projects off' ($i.has_projects -eq $false) ("has_projects=" + $i.has_projects)
if ($Class -eq 'profile') {
  Add-Result 'issues off (profile)' ($i.has_issues -eq $false) ("has_issues=" + $i.has_issues)
  Add-Result 'discussions off (profile)' ($i.has_discussions -eq $false) ("has_discussions=" + $i.has_discussions)
} elseif (-not $Class) {
  Add-Note 'issues and discussions' ("has_issues=" + $i.has_issues + ", has_discussions=" + $i.has_discussions + " (pass -Class to judge)")
}

# ---------- security ----------

$va = Get-Api @("repos/$Repo/vulnerability-alerts")
Add-Result 'Dependabot alerts on' ($va.Code -eq 0) ("GET vulnerability-alerts exit " + $va.Code)
$sf = Get-Api @("repos/$Repo/automated-security-fixes")
Add-Result 'Dependabot security updates on' ($sf.Json -and $sf.Json.enabled -eq $true) ("enabled=" + $(if ($sf.Json) { $sf.Json.enabled } else { 'unreadable' }))
if ($isPublic) {
  $sa = $i.security_and_analysis
  $ss = $null; $pp = $null
  if ($sa) { $ss = $sa.secret_scanning.status; $pp = $sa.secret_scanning_push_protection.status }
  Add-Result 'secret scanning on' ($ss -eq 'enabled') ("status=" + $ss)
  Add-Result 'push protection on' ($pp -eq 'enabled') ("status=" + $pp)
} else {
  Add-Note 'secret scanning, push protection, CodeQL' 'depend on the GitHub plan for private repos (check your plan); use the local scan in docs\system\repos.md'
}
if ($isPublic) {
  $pv = Get-Api @("repos/$Repo/private-vulnerability-reporting")
  Add-Result 'private vulnerability reporting on' ($pv.Json -and $pv.Json.enabled -eq $true) ("enabled=" + $(if ($pv.Json) { $pv.Json.enabled } else { 'unreadable' }))
} else {
  Add-Note 'private vulnerability reporting' 'public repos only'
}

# ---------- Actions ----------

$aw = Get-Api @("repos/$Repo/actions/permissions/workflow")
Add-Result 'Actions token read only' ($aw.Json -and $aw.Json.default_workflow_permissions -eq 'read') ("default_workflow_permissions=" + $(if ($aw.Json) { $aw.Json.default_workflow_permissions } else { 'unreadable' }))
Add-Result 'Actions cannot approve PRs' ($aw.Json -and $aw.Json.can_approve_pull_request_reviews -eq $false) ("can_approve_pull_request_reviews=" + $(if ($aw.Json) { $aw.Json.can_approve_pull_request_reviews } else { 'unreadable' }))
$ap = Get-Api @("repos/$Repo/actions/permissions")
Add-Result 'SHA pinning required (turn on after first green CI run)' ($ap.Json -and $ap.Json.sha_pinning_required -eq $true) ("sha_pinning_required=" + $(if ($ap.Json) { $ap.Json.sha_pinning_required } else { 'unreadable' }))

# ---------- rulesets ----------

$rl = Get-Api @("repos/$Repo/rulesets", '--jq', '.[] | [.id,.name] | @tsv')
$ids = @{}
if ($rl.Code -eq 0 -and $rl.Out) {
  foreach ($row in ($rl.Out -split "`r?`n")) {
    $p = $row -split "`t"
    if ($p.Count -ge 2) { $ids[$p[1]] = $p[0] }
  }
}
if ($rl.Code -ne 0) { Add-Result 'ruleset list readable' $false ($rl.Out.Substring(0, [Math]::Min(200, $rl.Out.Length))) }

function Get-RuleTypes($rs) { return @($rs.rules | ForEach-Object { $_.type }) }
function Test-RulesetCommon([string]$Name, $rs, [string]$Target, [string]$RefPattern) {
  $nb = @($rs.bypass_actors | Where-Object { $_ }).Count
  Add-Result "$Name active" ($rs.enforcement -eq 'active') ("enforcement=" + $rs.enforcement)
  Add-Result "$Name has no bypass actors" ($nb -eq 0) ("bypass_actors=" + $nb)
  Add-Result "$Name target" ($rs.target -eq $Target) ("target=" + $rs.target)
  $inc = @($rs.conditions.ref_name.include)
  Add-Result "$Name ref" ($inc -contains $RefPattern) ("include=" + ($inc -join ','))
}

$branchName = 'main-protection'
if (-not $isPublic) { $branchName = 'main-guard' }
if (-not $ids.ContainsKey($branchName)) {
  Add-Result "ruleset $branchName exists" $false 'not found'
} else {
  $d = Get-Api @("repos/$Repo/rulesets/" + $ids[$branchName])
  if (-not $d.Json) { Add-Result "ruleset $branchName readable" $false $d.Out }
  else {
    $rs = $d.Json
    Add-Result "ruleset $branchName exists" $true ("id " + $ids[$branchName])
    Test-RulesetCommon $branchName $rs 'branch' 'refs/heads/main'
    $types = Get-RuleTypes $rs
    $need = @('deletion', 'non_fast_forward')
    if ($isPublic -or $useStrict) { $need += @('required_linear_history', 'pull_request') }
    if ($isPublic) { $need += @('required_signatures', 'required_status_checks') }
    foreach ($t in $need) { Add-Result "$branchName rule $t" ($types -contains $t) $(if ($types -contains $t) { 'present' } else { 'missing' }) }
    $pr = $rs.rules | Where-Object { $_.type -eq 'pull_request' } | Select-Object -First 1
    if ($pr) {
      Add-Result "$branchName approvals" ($pr.parameters.required_approving_review_count -eq 0) ("required_approving_review_count=" + $pr.parameters.required_approving_review_count + ", want 0 (solo owner)")
      $mm = @($pr.parameters.allowed_merge_methods)
      Add-Result "$branchName squash only" ($mm.Count -eq 1 -and $mm[0] -eq 'squash') ("allowed_merge_methods=" + ($mm -join ','))
    }
    $sc = $rs.rules | Where-Object { $_.type -eq 'required_status_checks' } | Select-Object -First 1
    if ($sc) {
      $ctx = @($sc.parameters.required_status_checks | ForEach-Object { $_.context } | Sort-Object)
      $want = @($RequiredChecks | Sort-Object)
      $same = (($ctx -join ',') -eq ($want -join ','))
      # With no -Class the test check is unknown, so only require the base names.
      if (-not $Class) { $same = (@($BaseChecks | Where-Object { $ctx -notcontains $_ }).Count -eq 0) }
      Add-Result "$branchName required checks" $same ("have: " + ($ctx -join ', ') + "; want: " + ($want -join ', '))
    } elseif ($isPublic -or $useStrict) {
      if ($useStrict -and -not $isPublic) { Add-Note "$branchName required checks" 'none set; add them when ci.yml exists (setup-repo.ps1 -Strict adds them)' }
    }
  }
}

if (-not $ids.ContainsKey('release-tags')) {
  Add-Result 'ruleset release-tags exists' $false 'not found'
} else {
  $d = Get-Api @("repos/$Repo/rulesets/" + $ids['release-tags'])
  if (-not $d.Json) { Add-Result 'ruleset release-tags readable' $false $d.Out }
  else {
    Add-Result 'ruleset release-tags exists' $true ("id " + $ids['release-tags'])
    Test-RulesetCommon 'release-tags' $d.Json 'tag' 'refs/tags/v*'
    $types = Get-RuleTypes $d.Json
    foreach ($t in @('deletion', 'non_fast_forward')) { Add-Result "release-tags rule $t" ($types -contains $t) $(if ($types -contains $t) { 'present' } else { 'missing' }) }
  }
}

# ---------- labels ----------

$labelsPath = Join-Path $KitRoot 'templates\labels.yml'
if (-not (Test-Path -LiteralPath $labelsPath)) {
  Add-Result 'labels.yml readable' $false $labelsPath
} else {
  $want = Read-LabelNames $labelsPath
  $lr = Get-Api @("repos/$Repo/labels?per_page=100", '--paginate', '--jq', '.[] | [.name,.color,(.description // "")] | @tsv')
  $have = @{}
  foreach ($row in ($lr.Out -split "`r?`n")) {
    $p = $row -split "`t"
    if ($p.Count -ge 2) {
      $dsc = ''
      if ($p.Count -ge 3) { $dsc = $p[2] }
      $have[$p[0]] = [pscustomobject]@{ Color = $p[1].ToLower(); Description = $dsc }
    }
  }
  foreach ($l in $want) {
    $h = $have[$l.Name]
    if (-not $h) { Add-Result "label $($l.Name)" $false 'missing'; continue }
    $ok = ($h.Color -eq $l.Color -and $h.Description -ceq $l.Description)
    Add-Result "label $($l.Name)" $ok $(if ($ok) { 'color and description match' } else { "color=$($h.Color) want $($l.Color); description differs" })
  }
  $names = @($want | ForEach-Object { $_.Name })
  $extra = @($have.Keys | Where-Object { $names -notcontains $_ })
  Add-Result 'no extra labels' ($extra.Count -eq 0) $(if ($extra.Count -eq 0) { 'exactly the five' } else { ($extra -join ', ') + ' (delete by hand once the five exist)' })
}

# ---------- topics ----------

$tp = Get-Api @("repos/$Repo/topics")
$tn = @()
if ($tp.Json) { $tn = @($tp.Json.names) }
if ($isPublic) { Add-Result 'topics set' ($tn.Count -gt 0) ("count " + $tn.Count) }
else { Add-Note 'topics' ("count " + $tn.Count + " (optional on private repos)") }

# ---------- files ----------

Add-Result 'README.md' (Test-Path-Api 'README.md') 'root README'
$ciText = (& $Gh api "repos/$Repo/contents/.github/workflows/ci.yml" -H 'Accept: application/vnd.github.raw' 2>&1 | Out-String)
$ciOk = ($LASTEXITCODE -eq 0)
Stop-OnReadError $ciText $LASTEXITCODE
if ($ciOk) { foreach ($n in $RequiredChecks) { if ($ciText -notmatch ('(?m)^\s{2}' + [regex]::Escape($n) + ':\s*$')) { $ciOk = $false } } }
Add-Result 'ci.yml with the required jobs' $ciOk ('.github/workflows/ci.yml defines ' + ($RequiredChecks -join ', '))
Add-Result 'dependabot.yml' (Test-Path-Api '.github/dependabot.yml') '.github/dependabot.yml'
if ($isPublic) {
  Add-Result 'CODEOWNERS' (Test-Path-Api '.github/CODEOWNERS') '.github/CODEOWNERS'
  $sec = (Test-Path-Api 'SECURITY.md') -or (Test-Path-Api '.github/SECURITY.md') -or (Test-Path-Api 'docs/SECURITY.md')
  if (-not $sec) {
    $st = (& $Gh api "repos/alawein/.github/contents/SECURITY.md" --jq '.name' 2>&1 | Out-String).Trim()
    $sc2 = $LASTEXITCODE
    Stop-OnReadError $st $sc2
    $sec = ($sc2 -eq 0)
  }
  Add-Result 'SECURITY.md (repo or central alawein/.github)' $sec 'security policy reachable'
}
$cp = Get-Api @("repos/$Repo/community/profile")
if ($cp.Json) {
  $hasPr = ($null -ne $cp.Json.files.pull_request_template)
  Add-Result 'PR template (repo or central)' $hasPr 'community profile'
} else {
  Add-Result 'community profile readable' $false $cp.Out
}

# ---------- license ----------

$lic = Get-Api @("repos/$Repo/license")
$spdx = 'none'
if ($lic.Code -eq 0 -and $lic.Json -and $lic.Json.license) { $spdx = $lic.Json.license.spdx_id }
$wantLicense = $null   # $true required, $false none expected, $null unknown
switch ($Class) {
  'profile' { $wantLicense = $false }
  'site'    { $wantLicense = $false }
  'docs'    { $wantLicense = $isPublic }
  'tool'    { $wantLicense = $isPublic }
  'lab'     { $wantLicense = $isPublic }
}
if ($null -eq $wantLicense) { Add-Note 'license file' ("spdx=" + $spdx + " (pass -Class to judge)") }
elseif ($wantLicense) { Add-Result 'license file present' ($spdx -ne 'none') ("spdx=" + $spdx) }
else { Add-Result 'no license (class default)' ($spdx -eq 'none') ("spdx=" + $spdx) }
if ($spdx -eq 'NOASSERTION') { Add-Note 'license file' 'GitHub could not match the text to an SPDX id' }

# ---------- result ----------

Write-Host ''
Write-Host ('Result: {0} pass, {1} fail' -f $script:Pass, $script:Fail)
if ($script:Fail -gt 0) { exit 1 }
exit 0
