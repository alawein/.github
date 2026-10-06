<#
.SYNOPSIS
  Apply the alawein repo standard to one repo. Dry run by default.

.DESCRIPTION
  Applies, in this order: repo settings, Actions token permissions, Dependabot
  alerts and security updates, private vulnerability reporting (public repos),
  topics, labels (from templates\labels.yml), the branch ruleset, the tag
  ruleset, and (optional) SHA pinning. It also reads the first-time-contributor
  approval setting (public repos) and says what to change if it is weak.
  Every gh api call is printed before it runs. Without -Apply, reads run
  (GET) and writes are printed only. With -Apply, writes run one at a time,
  3 seconds apart, and the script stops on any 403 or 429. Reads stop on 403,
  429 or any error other than 404, so a failed read never turns into a write.
  Safe to run again: settings and topics are replaced with the same values,
  labels and rulesets are matched by name and updated in place. Existing
  rulesets are validated before any write; extra check requirements, producer
  bindings and parameterized protections are retained. Requires PowerShell 7.
  It never deletes anything; removal requires named owner approval.
  At the end of an -Apply run it calls verify-repo.ps1 to read everything back.

.PARAMETER Repo
  owner/name, for example alawein/example-app. Owner must be alawein.

.PARAMETER Class
  Repo class: profile, docs, tool, site, or lab (see docs\system\repos.md).
  Class profile turns Issues and Discussions off. Class site turns on -Strict.
  Class archive is refused, and so is any name that starts with ARCHIVE-.

.PARAMETER Language
  typescript (default) or python. Only a tool needs it: it picks the test check
  (node-ci or python-ci). A site uses node-ci and a lab uses python-ci. The
  profile and docs classes have no test check.

.PARAMETER Topics
  Up to 20 topics, lowercase with hyphens. Omit to leave topics alone.

.PARAMETER Strict
  Private repos only. Adds pull request (0 approvals, squash only) and linear
  history to the private ruleset, plus the required checks when ci.yml already
  defines them. Class site implies it.

.PARAMETER CheckProfile
  standard uses ci.yml and the class checks. hub-check is limited to the
  approved TypeScript hub and requires the check job in check.yml.

.PARAMETER RequirePrPolicy
  Opt in to the pr-policy gate in ci.yml. Private repos require -Strict,
  unless Class site already implies it. Incompatible with hub-check.

.PARAMETER EnableShaPinning
  Turns on sha_pinning_required. Use only after the first green CI run.

.PARAMETER Apply
  Write. Without it nothing is changed.

.EXAMPLE
  .\setup-repo.ps1 -Repo alawein/example-app -Class tool -Language python -Topics example,tooling
  .\setup-repo.ps1 -Repo alawein/example-app -Class tool -Language python -Topics example,tooling -Apply
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Repo,
  [Parameter(Mandatory = $true)][ValidateSet('profile', 'docs', 'tool', 'site', 'lab', 'archive')][string]$Class,
  [ValidateSet('typescript', 'python')][string]$Language = 'typescript',
  [string[]]$Topics = @(),
  [switch]$Strict,
  [switch]$RequirePrPolicy,
  [ValidateSet('standard', 'hub-check')][string]$CheckProfile = 'standard',
  [switch]$EnableShaPinning,
  [switch]$Apply
)

$ErrorActionPreference = 'Continue'
# The environment token can be stale and shadow the gh keyring login.
Remove-Item Env:GITHUB_TOKEN, Env:GH_TOKEN -ErrorAction SilentlyContinue

# Use gh.exe explicitly: an extensionless gh shim can sit earlier on PATH.
$GhCmd = Get-Command gh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$Gh = 'gh'
if ($GhCmd) { $Gh = $GhCmd.Source }

$KitRoot = Split-Path -Parent $PSScriptRoot
$Owner = 'alawein'
. (Join-Path $PSScriptRoot 'lib/check-policy.ps1')
$script:Failures = 0
$script:Skipped = 0

# ---------- naming rule ----------

function Test-RepoName([string]$Name) {
  $errs = @()
  if ($Name -eq '.github' -or $Name -eq 'alawein') { return $errs }   # the two special repos
  if ($Name.Length -gt 30) { $errs += 'longer than 30 characters' }
  if ($Name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    $errs += 'must be lowercase kebab-case: letters, digits, single hyphens, no underscore, dot, space or parenthesis'
  }
  if ($Name -match '^alawein-') { $errs += 'no owner prefix' }
  foreach ($tok in ($Name -split '-')) {
    if ($tok -match '^v?\d+$') { $errs += "token '$tok' looks like a version or date" }
    if ($tok -match '^(tmp|temp|old|final|copy|wip|draft|backup|retired|archive|deprecated)$') {
      $errs += "token '$tok' is a status word (only archive records carry one)"
    }
  }
  return $errs
}

# ---------- gh helpers ----------

function Write-Call([string]$Kind, [string[]]$GhArgs, [string]$Body) {
  $line = '{0} gh {1}' -f $Kind, ($GhArgs -join ' ')
  if ($Body) { $line += '   <- ' + (($Body -replace '\s+', ' ').Trim()) }
  Write-Host $line
}

# A read may fail only with 404 (not there). Any other failure (403, 429, 5xx, network) stops
# the script, so a failed read is never mistaken for "missing" and turned into a duplicate write.
# -Soft skips that rule; only `gh auth status` uses it (it has no HTTP status).
function Invoke-GhRead([string[]]$GhArgs, [switch]$Soft) {
  Write-Call 'GET  ' $GhArgs ''
  $text = (& $Gh @GhArgs 2>&1 | Out-String).Trim()
  $code = $LASTEXITCODE
  if ($code -ne 0 -and -not $Soft) {
    $http = ''
    if ($text -match 'HTTP (\d{3})') { $http = $Matches[1] }
    if ($http -ne '404') {
      Write-Host ('STOP: read failed (exit {0}, HTTP {1}): {2}' -f $code, $http, $text.Substring(0, [Math]::Min(300, $text.Length)))
      if ($text -match 'Upgrade to GitHub Pro') { Write-Host 'See docs\system\repos.md, section "Private repo limits and fallback".' }
      exit 2
    }
  }
  return [pscustomobject]@{ Code = $code; Out = $text }
}

# Method is PUT, POST or PATCH. Json is optional (a PUT with no body is fine).
function Invoke-GhWrite([string]$Method, [string]$Path, [string]$Json) {
  $a = @('api', '-X', $Method, $Path)
  if ($Json) { $a += @('--input', '-') }
  if (-not $Apply) {
    Write-Call 'DRY  ' $a $Json
    return $null
  }
  Write-Call 'WRITE' $a $Json
  if ($Json) { $text = ($Json | & $Gh @a 2>&1 | Out-String).Trim() }
  else { $text = (& $Gh @a 2>&1 | Out-String).Trim() }
  $code = $LASTEXITCODE
  Start-Sleep -Seconds 3
  if ($code -ne 0) {
    $script:Failures++
    Write-Host ('  FAILED (exit {0}): {1}' -f $code, ($text.Substring(0, [Math]::Min(300, $text.Length))))
    if ($text -match 'HTTP 403|HTTP 429|rate limit|Upgrade to GitHub Pro') {
      Write-Host 'STOP: 403 or 429. See docs\system\repos.md, section "Private repo limits and fallback".'
      exit 2
    }
  }
  return [pscustomobject]@{ Code = $code; Out = $text }
}

function Test-Json([string]$Text, [string]$Where) {
  try { [void]($Text | ConvertFrom-Json) } catch { Write-Host "STOP: bad JSON in $Where"; exit 2 }
}

# ---------- labels.yml (tiny reader for the fixed format) ----------

function Read-Labels([string]$Path) {
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
  foreach ($i in $items) {
    if (-not $i.Name -or -not $i.Color -or -not $i.Description -or $i.Description.Length -gt 100) {
      Write-Host "STOP: labels.yml entry '$($i.Name)' is incomplete or its description is over 100 characters"
      exit 2
    }
  }
  return $items
}

# ---------- checks before any call ----------

if ($Repo -notmatch '^([^/]+)/([^/]+)$') { Write-Host 'STOP: -Repo must look like alawein/name'; exit 2 }
$repoOwner = $Matches[1]; $repoName = $Matches[2]
if ($repoOwner -ne $Owner) { Write-Host "STOP: owner must be $Owner (got $repoOwner)"; exit 2 }
if ($repoName -cmatch '^ARCHIVE-') { Write-Host 'STOP: ARCHIVE- repos are retired; nothing is applied to them'; exit 2 }
$nameErrors = Test-RepoName $repoName
if ($nameErrors.Count -gt 0) {
  Write-Host "STOP: repo name '$repoName' breaks the naming rule:"
  $nameErrors | ForEach-Object { Write-Host "  - $_" }
  Write-Host 'Rule: lowercase kebab-case, at most 30 characters, no version, date, status word, owner prefix or underscore.'
  exit 2
}
if ($Class -eq 'archive') { Write-Host 'STOP: class archive gets no settings. Use scripts\archive-repos.ps1 (docs\archive.md).'; exit 2 }
try { $checkPolicy = Get-CheckPolicy -Repo $Repo -Class $Class -Language $Language -CheckProfile $CheckProfile -Strict:$Strict -RequirePrPolicy:$RequirePrPolicy }
catch { Write-Host ('STOP: ' + $_.Exception.Message); exit 2 }
$RequiredChecks = @($checkPolicy.RequiredChecks)
$workflowPath = $checkPolicy.WorkflowPath
if ($Topics.Count -gt 20) { Write-Host 'STOP: at most 20 topics'; exit 2 }
foreach ($t in $Topics) {
  if ($t -cnotmatch '^[a-z0-9][a-z0-9-]{0,49}$') { Write-Host "STOP: topic '$t' must be lowercase letters, digits, hyphens (max 50)"; exit 2 }
}
$labelsPath = Join-Path $KitRoot 'templates\labels.yml'
if (-not (Test-Path -LiteralPath $labelsPath)) { Write-Host "STOP: missing $labelsPath"; exit 2 }
$labels = Read-Labels $labelsPath
foreach ($f in @('rulesets\main-public.json', 'rulesets\main-private.json', 'rulesets\main-site.json', 'rulesets\main-hub.json', 'rulesets\tags.json', 'rulesets\repo-settings-public.json', 'rulesets\repo-settings-private.json')) {
  $p = Join-Path $KitRoot $f
  if (-not (Test-Path -LiteralPath $p)) { Write-Host "STOP: missing $p"; exit 2 }
  Test-Json (Get-Content -LiteralPath $p -Raw) $f
}

$mode = 'DRY RUN (reads only, nothing is written)'
if ($Apply) { $mode = 'APPLY (writes are live)' }
Write-Host ''
Write-Host "Repo: $Repo   Class: $Class   Mode: $mode"
Write-Host "Check profile: $CheckProfile; workflow: $workflowPath; checks: $($RequiredChecks -join ', ')"
Write-Host ''

$auth = Invoke-GhRead @('auth', 'status') -Soft
if ($auth.Out -notmatch 'Logged in') { Write-Host 'STOP: gh is not logged in (run gh auth login)'; exit 2 }

# ---------- read the repo ----------

$r = Invoke-GhRead @('api', "repos/$Repo")
if ($r.Code -ne 0) { Write-Host "STOP: cannot read $Repo`n$($r.Out)"; exit 2 }
$info = $r.Out | ConvertFrom-Json
if ($info.archived) { Write-Host 'STOP: repo is archived. Archived repos are not changed.'; exit 2 }
$isPublic = ($info.visibility -eq 'public')
if ($RequirePrPolicy -and -not $isPublic -and -not $checkPolicy.RequireChecks) { Write-Host 'STOP: RequirePrPolicy on a private repo requires -Strict (Class site implies it)'; exit 2 }
if ($CheckProfile -eq 'hub-check' -and $isPublic) { Write-Host 'STOP: hub-check is approved for the private hub only'; exit 2 }
$defaultBranch = $info.default_branch
Write-Host ("Facts: visibility={0} default_branch={1}" -f $info.visibility, $defaultBranch)
if ($CheckProfile -eq 'hub-check' -and $defaultBranch -ne 'main') {
  Write-Host "FAIL branch ruleset: default branch is '$defaultBranch'; hub-check requires main before setup."
  exit 1
}
$useStrict = $checkPolicy.RequireChecks
if ($isPublic -and $Strict) { Write-Host 'Note: -Strict only changes private repos; public repos already get the full ruleset.' }

# Is CI ready to be required? Two conditions:
#  - ci.yml defines every required job (Missing lists the absent ones);
#  - no workflow file still carries the all-zero placeholder pin (Placeholders lists the files).
# A required check that never reports would block every pull request.
function Get-CiState {
  $missing = @($RequiredChecks)
  $placeholders = @()
  $dir = Invoke-GhRead @('api', "repos/$Repo/contents/.github/workflows", '--jq', '.[] | select(.type == "file") | .name')
  if ($dir.Code -eq 0 -and $dir.Out) {
    foreach ($name in ($dir.Out -split "`r?`n")) {
      $name = $name.Trim()
      if ($name -notmatch '\.ya?ml$') { continue }
      $c = Invoke-GhRead @('api', ("repos/$Repo/contents/.github/workflows/" + [uri]::EscapeDataString($name)), '-H', 'Accept: application/vnd.github.raw')
      if ($c.Code -ne 0) { continue }
      if ($c.Out -match '(?<![0-9a-fA-F])0{40}(?![0-9a-fA-F])') { $placeholders += $name }
      if ($name -ceq (Split-Path -Leaf $workflowPath)) {
        $missing = @()
        foreach ($n in $RequiredChecks) {
          if ($c.Out -notmatch ('(?m)^\s{2}' + [regex]::Escape($n) + ':\s*$')) { $missing += $n }
        }
      }
    }
  }
  return [pscustomobject]@{ Missing = $missing; Placeholders = $placeholders }
}

# Read and validate the existing rulesets before the first settings write.
# A list/detail 404 is unavailable configuration, not proof of an empty list.
$rs = Invoke-GhRead @('api', "repos/$Repo/rulesets", '--paginate', '--slurp')
if ($rs.Code -ne 0) { Write-Host 'STOP: cannot read existing rulesets'; exit 2 }
$rulesetIds = @{}
$existingRulesets = @{}
try {
  $pages = $rs.Out | ConvertFrom-Json -NoEnumerate -ErrorAction Stop
  if ($pages -isnot [array] -or $pages.Count -eq 0) { throw 'expected paginated ruleset arrays' }
  foreach ($page in $pages) {
    if ($page -isnot [array]) { throw 'expected a ruleset array on each page' }
    foreach ($item in $page) {
      if ($item.id -notmatch '^[1-9][0-9]*$' -or $item.name -isnot [string] -or [string]::IsNullOrWhiteSpace($item.name) -or $rulesetIds.ContainsKey($item.name)) {
        throw 'malformed or ambiguous ruleset identity'
      }
      $rulesetIds[$item.name] = $item.id
    }
  }
} catch { Write-Host ('STOP: malformed ruleset list: ' + $_.Exception.Message); exit 2 }
foreach ($name in @('main-protection', 'main-guard', 'release-tags')) {
  if (-not $rulesetIds.ContainsKey($name)) { continue }
  $detail = Invoke-GhRead @('api', ("repos/$Repo/rulesets/" + $rulesetIds[$name]))
  if ($detail.Code -ne 0) { Write-Host "STOP: cannot read existing ruleset $name"; exit 2 }
  try {
    $parsed = $detail.Out | ConvertFrom-Json -ErrorAction Stop
    if ($parsed.name -cne $name) { throw 'ruleset name does not match the list' }
    [void]@(Get-StatusCheckRequirements $parsed)
  } catch { Write-Host ("STOP: malformed existing ruleset ${name}: " + $_.Exception.Message); exit 2 }
  $existingRulesets[$name] = $parsed
}

# ---------- 1. repo settings ----------

Write-Host "`n== 1. Repo settings =="
$settingsFile = 'rulesets\repo-settings-private.json'
if ($isPublic) { $settingsFile = 'rulesets\repo-settings-public.json' }
$settingsJson = Get-Content -LiteralPath (Join-Path $KitRoot $settingsFile) -Raw
if ($Class -eq 'profile') {
  $o = $settingsJson | ConvertFrom-Json
  $o | Add-Member -NotePropertyName has_issues -NotePropertyValue $false -Force
  $o | Add-Member -NotePropertyName has_discussions -NotePropertyValue $false -Force
  $settingsJson = ConvertTo-Json -InputObject $o -Depth 10
}
[void](Invoke-GhWrite 'PATCH' "repos/$Repo" $settingsJson)

# ---------- 2. Actions token ----------

Write-Host "`n== 2. Actions token: read only, cannot approve pull requests =="
[void](Invoke-GhWrite 'PUT' "repos/$Repo/actions/permissions/workflow" '{"default_workflow_permissions":"read","can_approve_pull_request_reviews":false}')

# ---------- 3. Dependabot ----------

Write-Host "`n== 3. Dependabot alerts and security updates (free on any plan) =="
[void](Invoke-GhWrite 'PUT' "repos/$Repo/vulnerability-alerts" '')
[void](Invoke-GhWrite 'PUT' "repos/$Repo/automated-security-fixes" '')
if ($isPublic) {
  Write-Host 'Private vulnerability reporting (the "Report a vulnerability" button that SECURITY.md points to):'
  [void](Invoke-GhWrite 'PUT' "repos/$Repo/private-vulnerability-reporting" '')
  $fp = Invoke-GhRead @('api', "repos/$Repo/actions/permissions/fork-pr-contributor-approval")
  $policy = ''
  if ($fp.Code -eq 0) { try { $policy = [string](($fp.Out | ConvertFrom-Json).approval_policy) } catch { $policy = '' } }
  if (@('first_time_contributors', 'all_external_contributors') -contains $policy) {
    Write-Host ("Fork PR approval: {0} (ok, first-time contributors need your approval)" -f $policy)
  } else {
    Write-Host ("Fork PR approval: '{0}' is weaker than the standard. Set it to first_time_contributors or stricter in Settings, Actions, General, Fork pull request workflows." -f $policy)
    $script:Skipped++
  }
} else {
  Write-Host 'Note: private repos have no private vulnerability reporting or fork approval setting. Secret scanning, push protection, CodeQL and dependency review depend on the GitHub plan (check your plan). Use the local scan in docs\system\repos.md.'
}

# ---------- 4. topics ----------

Write-Host "`n== 4. Topics =="
if ($Topics.Count -gt 0) {
  $tj = ConvertTo-Json -InputObject @{ names = @($Topics) } -Compress
  [void](Invoke-GhWrite 'PUT' "repos/$Repo/topics" $tj)
} else {
  Write-Host 'No -Topics given: topics left as they are.'
}

# ---------- 5. labels ----------

Write-Host "`n== 5. Labels (five canonical, from templates\labels.yml; additional labels retained) =="
$lr = Invoke-GhRead @('api', "repos/$Repo/labels?per_page=100", '--paginate', '--jq', '.[] | [.name,.color,(.description // "")] | @tsv')
$existing = @{}
if ($lr.Code -eq 0 -and $lr.Out) {
  foreach ($row in ($lr.Out -split "`r?`n")) {
    $p = $row -split "`t"
    if ($p.Count -ge 2) {
      $d = ''
      if ($p.Count -ge 3) { $d = $p[2] }
      $existing[$p[0].ToLower()] = [pscustomobject]@{ Name = $p[0]; Color = $p[1].ToLower(); Description = $d }
    }
  }
}
foreach ($l in $labels) {
  $key = $l.Name.ToLower()
  if ($existing.ContainsKey($key)) {
    $e = $existing[$key]
    if ($e.Name -ceq $l.Name -and $e.Color -eq $l.Color -and $e.Description -ceq $l.Description) {
      Write-Host ("label {0}: already correct" -f $l.Name); continue
    }
    $body = ConvertTo-Json -InputObject @{ new_name = $l.Name; color = $l.Color; description = $l.Description } -Compress
    [void](Invoke-GhWrite 'PATCH' ("repos/$Repo/labels/" + [uri]::EscapeDataString($e.Name)) $body)
    continue
  }
  $from = $null
  foreach ($al in $l.Aliases) { if ($existing.ContainsKey($al.ToLower())) { $from = $existing[$al.ToLower()]; break } }
  if ($from) {
    $body = ConvertTo-Json -InputObject @{ new_name = $l.Name; color = $l.Color; description = $l.Description } -Compress
    [void](Invoke-GhWrite 'PATCH' ("repos/$Repo/labels/" + [uri]::EscapeDataString($from.Name)) $body)
  } else {
    $body = ConvertTo-Json -InputObject @{ name = $l.Name; color = $l.Color; description = $l.Description } -Compress
    [void](Invoke-GhWrite 'POST' "repos/$Repo/labels" $body)
  }
}
$keep = @()
foreach ($l in $labels) { $keep += $l.Name.ToLower(); foreach ($al in $l.Aliases) { $keep += $al.ToLower() } }
$stock = @($existing.Keys | Where-Object { $keep -notcontains $_ })
if ($stock.Count -gt 0) {
  Write-Host ('Note: additional labels retained: {0}. Removal requires named owner approval.' -f ($stock -join ', '))
}

# ---------- 6. rulesets ----------

Write-Host "`n== 6. Rulesets =="
function Set-Ruleset([string]$Name, [string]$Json) {
  if ($rulesetIds.ContainsKey($Name)) {
    try {
      $desired = $Json | ConvertFrom-Json -ErrorAction Stop
      $merged = Merge-StatusCheckRules $desired $existingRulesets[$Name]
      $Json = ConvertTo-Json -InputObject $merged -Depth 30
    } catch { Write-Host ("STOP: cannot preserve ruleset ${Name}: " + $_.Exception.Message); exit 2 }
    [void](Invoke-GhWrite 'PUT' ("repos/$Repo/rulesets/" + $rulesetIds[$Name]) $Json)
  } else {
    [void](Invoke-GhWrite 'POST' "repos/$Repo/rulesets" $Json)
  }
}

if ($defaultBranch -ne 'main') {
  Write-Host "SKIP branch ruleset: default branch is '$defaultBranch', the standard is main only. Rename the branch first."
  $script:Skipped++
}
else {
  $ci = Get-CiState
  $missing = @($ci.Missing)
  $placeholders = @($ci.Placeholders)
  $ciReady = ($missing.Count -eq 0 -and $placeholders.Count -eq 0)
  if ($RequirePrPolicy -and -not $ciReady) { Write-Host 'FAIL opt-in policy: CI jobs and immutable pins must be ready before requiring pr-policy'; $script:Failures++ }
  if ($placeholders.Count -gt 0) {
    Write-Host ('Not ready: these workflow files still pin the all-zero placeholder SHA: ' + ($placeholders -join ', '))
    Write-Host '  Fix: replace every @0000000000000000000000000000000000000000 with a real commit SHA of alawein/.github (docs\ci.md, "After the first commit"), merge that, then run this again.'
  }
  if ($RequirePrPolicy -and -not $ciReady) {
    Write-Host 'SKIP branch ruleset: opt-in workflow readiness failed; existing protections are retained without an update.'
    $script:Skipped++
  }
  elseif ($isPublic) {
    if (-not $ciReady) {
      if ($missing.Count -gt 0) { Write-Host ("SKIP branch ruleset: $workflowPath is missing or lacks jobs: " + ($missing -join ', ')) }
      else { Write-Host 'SKIP branch ruleset: the placeholder pins above would keep the required checks from ever reporting.' }
      Write-Host '  A required check that never reports would block every pull request. Fix the above on main, then run this again.'
      $script:Skipped++
    } else {
      $pubJson = Get-Content -LiteralPath (Join-Path $KitRoot 'rulesets\main-public.json') -Raw
      if ($RequirePrPolicy -or $Class -in @('site', 'lab', 'tool')) {
        $po = $pubJson | ConvertFrom-Json
        foreach ($rule in $po.rules) {
          if ($rule.type -eq 'required_status_checks') { $rule.parameters.required_status_checks = @($RequiredChecks | ForEach-Object { [pscustomobject]@{ context = $_ } }) }
        }
        $pubJson = ConvertTo-Json -InputObject $po -Depth 12
      }
      Set-Ruleset 'main-protection' $pubJson
    }
  }
  else {
    $obj = (Get-Content -LiteralPath (Join-Path $KitRoot 'rulesets\main-private.json') -Raw) | ConvertFrom-Json
    if ($CheckProfile -eq 'hub-check') {
      if ($ciReady) {
        $obj = (Get-Content -LiteralPath (Join-Path $KitRoot 'rulesets\main-hub.json') -Raw) | ConvertFrom-Json
      } else {
        Write-Host ("FAIL branch ruleset: $workflowPath is missing or lacks jobs: " + ($missing -join ', '))
        $script:Failures++
        $script:Skipped++
        $obj = $null
      }
    }
    elseif ($Class -eq 'site' -and $ciReady) {
      $obj = (Get-Content -LiteralPath (Join-Path $KitRoot 'rulesets\main-site.json') -Raw) | ConvertFrom-Json
      if ($RequirePrPolicy) {
        ($obj.rules | Where-Object { $_.type -eq 'required_status_checks' }).parameters.required_status_checks = @($RequiredChecks | ForEach-Object { [pscustomobject]@{ context = $_ } })
      }
    }
    elseif ($useStrict) {
      $obj.rules += ('{"type":"required_linear_history"}' | ConvertFrom-Json)
      $obj.rules += ('{"type":"pull_request","parameters":{"required_approving_review_count":0,"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false,"allowed_merge_methods":["squash"]}}' | ConvertFrom-Json)
      if ($ciReady) {
        $ctxs = @($RequiredChecks | ForEach-Object { @{ context = $_ } })
        $scRule = @{ type = 'required_status_checks'; parameters = @{ strict_required_status_checks_policy = $false; do_not_enforce_on_create = $false; required_status_checks = $ctxs } }
        $obj.rules += ((ConvertTo-Json -InputObject $scRule -Depth 6) | ConvertFrom-Json)
      } else {
        Write-Host ("Note: $workflowPath missing or incomplete, or placeholder pins remain, so the strict private ruleset has no required checks yet. Run again after CI is ready.")
      }
    }
    if ($obj) { Set-Ruleset 'main-guard' (ConvertTo-Json -InputObject $obj -Depth 12) }
  }
}
Set-Ruleset 'release-tags' (Get-Content -LiteralPath (Join-Path $KitRoot 'rulesets\tags.json') -Raw)

# ---------- 7. SHA pinning (optional) ----------

Write-Host "`n== 7. SHA pinning =="
if ($EnableShaPinning) {
  $ap = Invoke-GhRead @('api', "repos/$Repo/actions/permissions")
  if ($ap.Code -eq 0) {
    $cur = $ap.Out | ConvertFrom-Json
    $b = [ordered]@{ enabled = [bool]$cur.enabled; sha_pinning_required = $true }
    if ($cur.PSObject.Properties.Name -contains 'allowed_actions' -and $cur.allowed_actions) { $b['allowed_actions'] = $cur.allowed_actions }
    [void](Invoke-GhWrite 'PUT' "repos/$Repo/actions/permissions" (ConvertTo-Json -InputObject $b -Compress))
  } else { Write-Host ('Cannot read actions permissions: ' + $ap.Out); $script:Failures++ }
} else {
  Write-Host 'Skipped. After the first green CI run, run again with -EnableShaPinning.'
}

# ---------- read-back ----------

Write-Host "`n== Read-back =="
if ($Apply) {
  $vArgs = @{ Repo = $Repo; Class = $Class; Language = $Language; CheckProfile = $CheckProfile; RequirePrPolicy = [bool]$RequirePrPolicy }
  if ($useStrict) { $vArgs['Strict'] = $true }
  & (Join-Path $PSScriptRoot 'verify-repo.ps1') @vArgs
  Write-Host ("`nWrite failures: {0}   Skipped steps: {1}" -f $script:Failures, $script:Skipped)
  if ($script:Failures -gt 0) { exit 1 }
} else {
  Write-Host ("Dry run done. Nothing was written. Skipped steps: {0}. Add -Apply to write." -f $script:Skipped)
  if ($script:Failures -gt 0) { exit 1 }
  exit 0
}
