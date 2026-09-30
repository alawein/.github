<#
.SYNOPSIS
Read-only audit of every archived repo: is it isolated and inert?

.DESCRIPTION
Lists every repo under -Owner whose name starts with ARCHIVE- and checks it with GET
requests only. It never writes, never deletes, and never prints a secret value (it only
counts secret names). Prints PASS, WARN or FAIL per repo and a summary.

Checks per repo
  archived flag on, topics (archived, do-not-use, stats-only, origin-<year>),
  description starts with "[ARCHIVE] ", homepage empty, Pages off, Actions off,
  webhook count 0, deploy key count 0, secret name count 0, workflow file count (info),
  custom property status=archived (org repos only).

Checks per org (only when -Owner is an organization)
  Actions disabled for all repositories, no org webhooks, no org secrets or variables,
  installed app count, base permission none, repo creation off, private forking off.

What it cannot see: apps installed on a personal account have no per-repo API, so the app
count is WARN there (verify by hand: Settings, Applications, Installed GitHub Apps).

.PARAMETER Owner
Account or org to audit. Default alawein. Use alawein-archive after the transfer.
.PARAMETER MapPath
Optional map CSV. Repos whose decision is keep may still show a homepage; that is WARN, not FAIL.
.PARAMETER Prefix
Name prefix to audit. Default ARCHIVE-. A longer value (a full repo name) audits one repo, for a spot check.
.PARAMETER PauseMs
Wait between repos, in milliseconds. Default 300.
.PARAMETER OutFile
Optional NDJSON file for the results.

Exit code: 0 when no FAIL, 4 when any FAIL, 2 on a 403 or 429, 1 on a setup error.

.EXAMPLE
.\audit-archive.ps1
.\audit-archive.ps1 -Owner alawein-archive
.\audit-archive.ps1 -MapPath .\archive-rename-map.csv
#>
[CmdletBinding()]
param(
    [string]$Owner = 'alawein',
    [string]$MapPath = '',
    [string]$Prefix = 'ARCHIVE-',
    [int]$PauseMs = 300,
    [string]$OutFile = ''
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

# The env token can be stale; gh then uses its own keyring login.
Remove-Item Env:GITHUB_TOKEN, Env:GH_TOKEN -ErrorAction SilentlyContinue

$GhCmd = Get-Command gh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $GhCmd) { Write-Host 'STOP: gh.exe not found'; exit 1 }
$Gh = $GhCmd.Source

if ($Prefix -cnotmatch '^[A-Za-z0-9._-]+$') { Write-Host 'STOP: -Prefix has bad characters'; exit 1 }
if ($Owner -cnotmatch '^[A-Za-z0-9._-]+$' -or $Owner -cmatch '^\.+$') { Write-Host 'STOP: -Owner has bad characters'; exit 1 }

# The only way this script talks to GitHub. Plain GET, no method flag, no body.
function Get-Api {
    param([string]$Path)
    if ($Path -cnotmatch '^[A-Za-z0-9/_.?=&-]+$') { throw ('unsafe API path: ' + $Path) }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { $out = & $Gh api $Path 2>&1; $code = $LASTEXITCODE }
    finally { $ErrorActionPreference = $prev }
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    $http = ''
    if ($text -match 'HTTP (\d{3})') { $http = $Matches[1] }
    if ($text -match '(?i)secondary rate limit|rate limit exceeded') { if (-not $http) { $http = '429' } }
    if ($code -eq 0) {
        $data = $null
        if ($text.Trim()) { $data = $text | ConvertFrom-Json }
        return [pscustomobject]@{ Ok = $true; Http = '200'; Data = $data }
    }
    if ($http -eq '429') { Write-Host 'STOP: rate limited (429). Wait, then rerun.'; exit 2 }
    return [pscustomobject]@{ Ok = $false; Http = $http; Data = $null }
}

# An empty JSON array can arrive as null in Windows PowerShell, so count with care.
function Get-Count {
    param($Data)
    if ($null -eq $Data) { return 0 }
    return @($Data).Count
}

$st = & $Gh auth status 2>&1 | Out-String
if ($st -notmatch 'Logged in') { Write-Host 'STOP: gh is not logged in (gh auth login)'; exit 1 }

$keepNames = @{}
if ($MapPath) {
    if (-not (Test-Path -LiteralPath $MapPath)) { Write-Host ('STOP: map not found: ' + $MapPath); exit 1 }
    foreach ($r in (Import-Csv -LiteralPath $MapPath -Encoding UTF8)) { if ($r.decision -ceq 'keep') { $keepNames[$r.new_name] = $true } }
}

$Script:Results = New-Object System.Collections.Generic.List[object]
function Add-Check {
    param([string]$Scope, [string]$Check, [string]$Status, [string]$Detail)
    $Script:Results.Add([pscustomobject]@{ Scope = $Scope; Check = $Check; Status = $Status; Detail = $Detail })
}

# ---------- who is the owner ----------
$who = Get-Api ('users/' + $Owner)
if (-not $who.Ok) { Write-Host ('STOP: cannot read ' + $Owner + ' (HTTP ' + $who.Http + ')'); exit 1 }
$isOrg = ($who.Data.type -ceq 'Organization')
Write-Host ('Audit of ' + $Owner + ' (' + $who.Data.type + '). Read-only GETs.')

# ---------- org checks ----------
if ($isOrg) {
    $s = "org:$Owner"
    $o = Get-Api ('orgs/' + $Owner)
    if ($o.Ok) {
        $d = $o.Data
        if ("$($d.default_repository_permission)" -ceq 'none') { Add-Check $s 'base permission none' 'PASS' '' } else { Add-Check $s 'base permission none' 'FAIL' ("now: $($d.default_repository_permission)") }
        if ($d.members_can_create_repositories -eq $false) { Add-Check $s 'repo creation off' 'PASS' '' } else { Add-Check $s 'repo creation off' 'FAIL' 'members can create repos' }
        if ($d.members_can_fork_private_repositories -eq $false) { Add-Check $s 'private forking off' 'PASS' '' } else { Add-Check $s 'private forking off' 'FAIL' 'private forking allowed' }
    }
    else { Add-Check $s 'org settings' 'WARN' ('unreadable (HTTP ' + $o.Http + '); verify: gh api orgs/' + $Owner) }

    $ap = Get-Api ('orgs/' + $Owner + '/actions/permissions')
    if ($ap.Ok) {
        if ("$($ap.Data.enabled_repositories)" -ceq 'none') { Add-Check $s 'Actions disabled for all repos' 'PASS' '' } else { Add-Check $s 'Actions disabled for all repos' 'FAIL' ("now: $($ap.Data.enabled_repositories)") }
    }
    else { Add-Check $s 'Actions disabled for all repos' 'WARN' ('unreadable (HTTP ' + $ap.Http + '); verify: gh api orgs/' + $Owner + '/actions/permissions') }

    $hk = Get-Api ('orgs/' + $Owner + '/hooks')
    if ($hk.Ok) { $n = (Get-Count $hk.Data); if ($n -eq 0) { Add-Check $s 'org webhooks 0' 'PASS' '' } else { Add-Check $s 'org webhooks 0' 'FAIL' "$n found" } }
    else { Add-Check $s 'org webhooks 0' 'WARN' ('unreadable (HTTP ' + $hk.Http + ')') }

    $sec = Get-Api ('orgs/' + $Owner + '/actions/secrets')
    if ($sec.Ok) { $n = [int]$sec.Data.total_count; if ($n -eq 0) { Add-Check $s 'org secrets 0' 'PASS' '' } else { Add-Check $s 'org secrets 0' 'FAIL' "$n names" } }
    else { Add-Check $s 'org secrets 0' 'WARN' ('unreadable (HTTP ' + $sec.Http + ')') }

    $var = Get-Api ('orgs/' + $Owner + '/actions/variables')
    if ($var.Ok) { $n = [int]$var.Data.total_count; if ($n -eq 0) { Add-Check $s 'org variables 0' 'PASS' '' } else { Add-Check $s 'org variables 0' 'FAIL' "$n names" } }
    else { Add-Check $s 'org variables 0' 'WARN' ('unreadable (HTTP ' + $var.Http + ')') }

    $ins = Get-Api ('orgs/' + $Owner + '/installations')
    if ($ins.Ok) { $n = [int]$ins.Data.total_count; if ($n -eq 0) { Add-Check $s 'installed apps 0' 'PASS' '' } else { Add-Check $s 'installed apps 0' 'FAIL' "$n installed" } }
    else { Add-Check $s 'installed apps 0' 'WARN' ('unreadable (HTTP ' + $ins.Http + '); verify by hand: org Settings, GitHub Apps') }

    $oc = Get-Api ('orgs/' + $Owner + '/outside_collaborators')
    if ($oc.Ok) { $n = (Get-Count $oc.Data); if ($n -eq 0) { Add-Check $s 'outside collaborators 0' 'PASS' '' } else { Add-Check $s 'outside collaborators 0' 'FAIL' "$n found" } }
    else { Add-Check $s 'outside collaborators 0' 'WARN' ('unreadable (HTTP ' + $oc.Http + ')') }
}

# ---------- list the repos ----------
$lr = & $Gh repo list $Owner --limit 1000 --json name,isArchived 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) { Write-Host 'STOP: cannot list repos (run gh auth status)'; exit 1 }
$repos = @($lr | ConvertFrom-Json)
$targets = @($repos | Where-Object { $_.name.StartsWith($Prefix) } | Sort-Object name)
$retiredLeft = @($repos | Where-Object { $_.name -cmatch '^RETIRED-' })
$archivedOther = @($repos | Where-Object { $_.isArchived -and -not $_.name.StartsWith($Prefix) -and $_.name -cnotmatch '^RETIRED-' })
Write-Host ('Repos under ' + $Owner + ': ' + $repos.Count + ', named ' + $Prefix + '*: ' + $targets.Count)
if ($targets.Count -eq 0) { Write-Host ('No repo starts with ' + $Prefix + ' yet. Nothing to audit.') }

# ---------- per repo ----------
foreach ($t in $targets) {
    $n = $t.name
    $p = 'repos/' + $Owner + '/' + $n
    $g = Get-Api $p
    if (-not $g.Ok) { Add-Check $n 'read repo' 'FAIL' ('HTTP ' + $g.Http); continue }
    $d = $g.Data

    if ($d.archived) { Add-Check $n 'archived' 'PASS' '' } else { Add-Check $n 'archived' 'FAIL' 'archived flag is off' }

    $top = @($d.topics)
    $miss = @()
    foreach ($need in @('archived', 'do-not-use', 'stats-only')) { if ($top -cnotcontains $need) { $miss += $need } }
    if (@($top | Where-Object { $_ -cmatch '^origin-\d{4}$' }).Count -lt 1) { $miss += 'origin-<year>' }
    if ($miss.Count -eq 0) { Add-Check $n 'topics' 'PASS' '' } else { Add-Check $n 'topics' 'FAIL' ('missing: ' + ($miss -join ', ')) }

    if ("$($d.description)".StartsWith('[ARCHIVE] ')) { Add-Check $n 'description prefix' 'PASS' '' } else { Add-Check $n 'description prefix' 'FAIL' 'no [ARCHIVE] prefix' }

    if (-not "$($d.homepage)") { Add-Check $n 'homepage empty' 'PASS' '' }
    elseif ($keepNames.ContainsKey($n)) { Add-Check $n 'homepage empty' 'WARN' 'homepage set; map says keep (owner decision)' }
    else { Add-Check $n 'homepage empty' 'FAIL' 'homepage is set' }

    if ($d.has_pages) { Add-Check $n 'Pages off' 'FAIL' 'Pages is published' } else { Add-Check $n 'Pages off' 'PASS' '' }

    $ac = Get-Api ($p + '/actions/permissions')
    if ($ac.Ok) { if ($ac.Data.enabled -eq $false) { Add-Check $n 'Actions off' 'PASS' '' } else { Add-Check $n 'Actions off' 'FAIL' 'Actions is enabled' } }
    else { Add-Check $n 'Actions off' 'WARN' ('unreadable (HTTP ' + $ac.Http + ')') }

    $hk = Get-Api ($p + '/hooks')
    if ($hk.Ok) { $c = (Get-Count $hk.Data); if ($c -eq 0) { Add-Check $n 'webhooks 0' 'PASS' '' } else { Add-Check $n 'webhooks 0' 'FAIL' "$c found" } }
    else { Add-Check $n 'webhooks 0' 'WARN' ('unreadable (HTTP ' + $hk.Http + ')') }

    $ky = Get-Api ($p + '/keys')
    if ($ky.Ok) { $c = (Get-Count $ky.Data); if ($c -eq 0) { Add-Check $n 'deploy keys 0' 'PASS' '' } else { Add-Check $n 'deploy keys 0' 'FAIL' "$c found" } }
    else { Add-Check $n 'deploy keys 0' 'WARN' ('unreadable (HTTP ' + $ky.Http + ')') }

    $sc = Get-Api ($p + '/actions/secrets')
    if ($sc.Ok) { $c = [int]$sc.Data.total_count; if ($c -eq 0) { Add-Check $n 'secret names 0' 'PASS' '' } else { Add-Check $n 'secret names 0' 'FAIL' "$c names" } }
    else { Add-Check $n 'secret names 0' 'WARN' ('unreadable (HTTP ' + $sc.Http + ')') }

    $wf = Get-Api ($p + '/actions/workflows')
    if ($wf.Ok) { Add-Check $n 'workflow files' 'PASS' ([string]$wf.Data.total_count + ' (info only; Actions is what matters)') }

    if ($isOrg) {
        $pv = Get-Api ($p + '/properties/values')
        if ($pv.Ok) {
            $ok = $false
            foreach ($x in @($pv.Data)) { if ($x.property_name -ceq 'status' -and "$($x.value)" -ceq 'archived') { $ok = $true } }
            if ($ok) { Add-Check $n 'property status=archived' 'PASS' '' } else { Add-Check $n 'property status=archived' 'WARN' 'not set (needs the org property)' }
        }
        else { Add-Check $n 'property status=archived' 'WARN' ('unreadable (HTTP ' + $pv.Http + ')') }
    }
    Start-Sleep -Milliseconds $PauseMs
}

# ---------- account-level notes ----------
if (-not $isOrg) {
    Add-Check "account:$Owner" 'installed apps' 'WARN' 'no per-repo API on a personal account; verify by hand: Settings, Applications, Installed GitHub Apps, each app: Repository access'
}
if ($retiredLeft.Count -gt 0) { Add-Check "account:$Owner" 'old RETIRED- names left' 'WARN' ([string]$retiredLeft.Count + ' repos still use the old prefix (rename batches not finished)') }
if ($archivedOther.Count -gt 0) { Add-Check "account:$Owner" 'archived without ARCHIVE- name' 'WARN' ([string]$archivedOther.Count + ' archived repos have another name') }

# ---------- report ----------
Write-Host ''
$repoNames = @($targets | ForEach-Object { $_.name })
$failRepos = 0; $warnRepos = 0; $passRepos = 0
foreach ($n in $repoNames) {
    $rs = @($Script:Results | Where-Object { $_.Scope -ceq $n })
    $f = @($rs | Where-Object { $_.Status -ceq 'FAIL' })
    $w = @($rs | Where-Object { $_.Status -ceq 'WARN' })
    $tag = 'PASS'
    if ($f.Count -gt 0) { $tag = 'FAIL'; $failRepos++ } elseif ($w.Count -gt 0) { $tag = 'WARN'; $warnRepos++ } else { $passRepos++ }
    Write-Host ('{0} {1}' -f $tag, $n)
    foreach ($x in ($f + $w)) { Write-Host ('    {0} {1}: {2}' -f $x.Status, $x.Check, $x.Detail) }
}
$extra = @($Script:Results | Where-Object { $_.Scope -cnotin $repoNames })
$orgFail = @($extra | Where-Object { $_.Status -ceq 'FAIL' }).Count
if ($extra.Count -gt 0) {
    Write-Host ''
    Write-Host 'Org and account checks'
    foreach ($x in $extra) { Write-Host ('  {0} {1} {2}: {3}' -f $x.Status, $x.Scope, $x.Check, $x.Detail) }
}
Write-Host ''
Write-Host ('Summary: repos audited {0}, PASS {1}, WARN {2}, FAIL {3}. Org or account FAIL: {4}.' -f $repoNames.Count, $passRepos, $warnRepos, $failRepos, $orgFail)

if ($OutFile) {
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    foreach ($x in $Script:Results) {
        $o = [ordered]@{ ts = $ts; owner = $Owner; scope = $x.Scope; check = $x.Check; status = $x.Status; detail = $x.Detail }
        Add-Content -LiteralPath $OutFile -Value ($o | ConvertTo-Json -Compress) -Encoding UTF8
    }
    Write-Host ('Results written to ' + $OutFile)
}
if ($failRepos -gt 0 -or $orgFail -gt 0) { exit 4 } else { exit 0 }
