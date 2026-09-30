<#
.SYNOPSIS
Archive old repos in small batches: rename to ARCHIVE-, describe, tag, clear the homepage,
turn Actions off, archive. A separate mode moves renamed repos to the archive org.

.DESCRIPTION
Reads a map CSV (see docs/archive.md for the columns). Dry run by default: it prints the
plan and makes no network call. With -Apply it writes, one repo at a time, after you type
the confirmation it prints. It never deletes anything: no repo, no webhook, no Pages site,
no branch. Those are owner steps.

Per repo, in order: unarchive (needed to edit), rename, edit description, set topics,
clear homepage, turn Actions off, archive again. It waits between writes, stops on any 403
or 429 (or any other error), reads each repo back, and logs every step to a local NDJSON file.

Modes
  -Plan (default)        dry run, offline, prints the plan and the typed phrase
  -Apply                 writes one batch; types: APPLY <batch id>
  -Verify                read-only GETs, compares live state with the map
  -Rollback [-Apply]     reverses rename, description, topics and homepage; types: APPLY <batch id> ROLLBACK
  -Transfer [-Apply]     moves already renamed repos to the archive org; types: TRANSFER <batch id>
                         refuses unless the org exists and you own it
  -Transfer -Verify      read-only check of the repos under the org

.PARAMETER MapPath
Path to the map CSV. Keep it out of git (the kit .gitignore ignores *.csv).
.PARAMETER Batch
One batch id such as AR1. Default all (plan and -Verify only; writing needs one batch).
.PARAMETER Owner
Account that holds the repos now. Letters, digits, dot, underscore and hyphen only.
Use the archive org name here for -Apply or -Verify after a transfer.
.PARAMETER Org
Archive org that -Transfer moves repos into. Default alawein-archive.
.PARAMETER PauseSeconds
Wait after every write. Default 3.
.PARAMETER LogPath
NDJSON log file. Default: a new file under the local app data folder.

.EXAMPLE
.\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0
.\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0 -Apply
.\archive-repos.ps1 -MapPath .\archive-rename-map.csv -Batch AR0 -Transfer
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$MapPath,
    [string]$Batch = 'all',
    [string]$Owner = 'alawein',
    [string]$Org = 'alawein-archive',
    [switch]$Plan,
    [switch]$Apply,
    [switch]$Transfer,
    [switch]$Rollback,
    [switch]$Verify,
    [int]$PauseSeconds = 3,
    [string]$LogPath = ''
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

# The env token can be stale; gh then uses its own keyring login.
Remove-Item Env:GITHUB_TOKEN, Env:GH_TOKEN -ErrorAction SilentlyContinue

# Use gh.exe explicitly: an extensionless gh shim can sit earlier on PATH.
$GhCmd = Get-Command gh.exe -ErrorAction SilentlyContinue | Select-Object -First 1
$Gh = 'gh.exe'
if ($GhCmd) { $Gh = $GhCmd.Source }

$Prefix = 'ARCHIVE-'
$DescPrefix = '[ARCHIVE] '
$MaxDesc = 350
$Script:LogFile = $null
$Script:Mode = 'init'
$Script:CurBatch = ''

function Write-Log {
    param([string]$Repo, [string]$Step, [bool]$Ok, [string]$Http, [string]$Detail)
    if (-not $Script:LogFile) { return }
    $o = [ordered]@{
        ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        mode = $Script:Mode; batch = $Script:CurBatch; repo = $Repo
        step = $Step; ok = $Ok; http = $Http; detail = $Detail
    }
    Add-Content -LiteralPath $Script:LogFile -Value ($o | ConvertTo-Json -Compress) -Encoding UTF8
}

function Stop-Run {
    param([string]$Message, [int]$Code)
    Write-Host ''
    Write-Host ('STOP: ' + $Message)
    Write-Log '' 'stop' $false '' $Message
    if ($Script:LogFile) { Write-Host ('Log: ' + $Script:LogFile) }
    exit $Code
}

# Writes every non-ASCII character of a JSON body as a \uXXXX escape, so the bytes sent are
# plain ASCII whatever the console code page is. JSON readers decode the escape to the same text.
function ConvertTo-AsciiJson {
    param([string]$Json)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $Json.ToCharArray()) {
        if ([int]$ch -gt 126) { [void]$sb.Append(('\u{0:x4}' -f [int]$ch)) } else { [void]$sb.Append($ch) }
    }
    return $sb.ToString()
}

# One form for comparing text read from the API with text from the map: composed Unicode,
# LF line ends, no edge spaces. A null reads as empty.
function Get-NormText {
    param($Text)
    if ($null -eq $Text) { return '' }
    return ("$Text".Normalize([System.Text.NormalizationForm]::FormC) -replace "`r`n?", "`n").Trim()
}

# Runs gh. Body (JSON text) goes in through stdin. Returns Code, Http and Text.
# Reads and writes are UTF-8 on purpose: the console code page (often OEM) would garble
# an em dash or any other non-ASCII character in a description.
function Invoke-Gh {
    param([string[]]$GhArgs, [string]$Body = '')
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $prevOut = $OutputEncoding
    $prevCon = $null
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    try {
        $OutputEncoding = $utf8
        try { $prevCon = [Console]::OutputEncoding; [Console]::OutputEncoding = $utf8 } catch { $prevCon = $null }
        if ($Body) { $out = (ConvertTo-AsciiJson $Body) | & $Gh @GhArgs --input - 2>&1 }
        else { $out = & $Gh @GhArgs 2>&1 }
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $prev
        $OutputEncoding = $prevOut
        if ($prevCon) { try { [Console]::OutputEncoding = $prevCon } catch { $null = $_ } }
    }
    $text = (($out | ForEach-Object { "$_" }) -join "`n")
    $http = ''
    if ($text -match 'HTTP (\d{3})') { $http = $Matches[1] }
    if ($text -match '(?i)secondary rate limit|rate limit exceeded') { if (-not $http) { $http = '429' } }
    return [pscustomobject]@{ Code = $code; Http = $http; Text = $text }
}

# Read one repo. A 404 means "not there". So does a redirect (301, 302, 307, 308): a renamed
# repo answers on its old name with a redirect, so that name is no longer the repo's name.
# Any other failure stops the run.
function Get-Repo {
    param([string]$Name, [string]$Who = $Owner)
    $r = Invoke-Gh @('api', ('repos/{0}/{1}' -f $Who, $Name))
    if ($r.Code -eq 0) { return [pscustomobject]@{ Found = $true; Http = ''; Data = ($r.Text | ConvertFrom-Json) } }
    if (@('404', '301', '302', '307', '308') -cnotcontains $r.Http) { Stop-Run ('HTTP ' + $r.Http + ' (exit ' + $r.Code + ') on read of ' + $Name) 2 }
    return [pscustomobject]@{ Found = $false; Http = $r.Http; Data = $null }
}

# Find the repo for a rename step, resuming a run that already renamed it. Tries the target
# name first (a write to the old name of a renamed repo fails with HTTP 307), then the source
# name. A read of the old name can follow the redirect, so the name the API reports wins.
# Returns Found, Name (the name to write to now) and Data.
function Resolve-Repo {
    param([string]$From, [string]$To, [string]$Who = $Owner)
    if ($From -cne $To) {
        $n = Get-Repo $To $Who
        if ($n.Found -and $n.Data.name -ceq $To) { return [pscustomobject]@{ Found = $true; Name = $To; Data = $n.Data } }
    }
    $o = Get-Repo $From $Who
    if (-not $o.Found) { return [pscustomobject]@{ Found = $false; Name = ''; Data = $null } }
    return [pscustomobject]@{ Found = $true; Name = "$($o.Data.name)"; Data = $o.Data }
}

# Read the Actions switch. Returns $true, $false, or $null when it cannot be read.
function Get-ActionsEnabled {
    param([string]$Name, [string]$Who = $Owner)
    $r = Invoke-Gh @('api', ('repos/{0}/{1}/actions/permissions' -f $Who, $Name))
    if ($r.Code -ne 0) {
        if ($r.Http -eq '403' -or $r.Http -eq '429') { Stop-Run ('HTTP ' + $r.Http + ' on read of Actions state for ' + $Name) 2 }
        return $null
    }
    return [bool](($r.Text | ConvertFrom-Json).enabled)
}

# One write. Stops the whole run on any failure.
function Send-Write {
    param([string]$Repo, [string]$Step, [string]$Method, [string]$Path, [string]$Body)
    $r = Invoke-Gh @('api', '-X', $Method, $Path) $Body
    $ok = ($r.Code -eq 0)
    $detail = $Body
    if (-not $ok) { $detail = $Body + ' => ' + ($r.Text -replace '\s+', ' ') }
    Write-Log $Repo $Step $ok $r.Http $detail
    if (-not $ok) {
        if ($r.Http -eq '403' -or $r.Http -eq '429') { Stop-Run ('HTTP ' + $r.Http + ' at ' + $Step + ' on ' + $Repo + '. Wait, then rerun the same batch (it resumes).') 2 }
        Stop-Run ('step ' + $Step + ' failed on ' + $Repo + ' (HTTP ' + $r.Http + '). Check the log, then rerun the same batch (it resumes). The repo may be left unarchived.') 3
    }
    Write-Host ('    ok  ' + $Step)
    Start-Sleep -Seconds $PauseSeconds
}

function ConvertTo-TopicJson {
    param([string[]]$Names)
    $q = @($Names | Where-Object { $_ } | ForEach-Object { '"' + $_ + '"' })
    return '{"names":[' + ($q -join ',') + ']}'
}

function Split-Topics {
    param([string]$Text)
    return @(($Text -split ';') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Test-SameSet {
    param([string[]]$A, [string[]]$B)
    $x = (@($A) | Sort-Object) -join ','
    $y = (@($B) | Sort-Object) -join ','
    return ($x -ceq $y)
}

# Names and the owner go into API paths, so check them before anything else, in every mode.
# A name made only of dots would climb out of the repos/ path, so it is refused too.
function Test-SafeName {
    param([string]$Value)
    return ($Value -cmatch '^[A-Za-z0-9._-]+$') -and ($Value -cnotmatch '^\.+$')
}

# ---------- modes ----------
if ($Plan -and $Apply) { Stop-Run '-Plan and -Apply cancel each other; use one' 1 }
if ($Transfer -and $Rollback) { Stop-Run '-Transfer and -Rollback cannot be combined (a transfer back is an owner step, see docs/archive.md)' 1 }
if ($Verify -and ($Apply -or $Plan)) { Stop-Run '-Verify is read only; do not combine it with -Apply or -Plan' 1 }
if (-not (Test-SafeName $Owner)) { Stop-Run ('-Owner must match [A-Za-z0-9._-]+ (got: ' + $Owner + '); nothing was sent') 1 }
if (-not (Test-SafeName $Org)) { Stop-Run ('-Org must match [A-Za-z0-9._-]+ (got: ' + $Org + '); nothing was sent') 1 }
if (-not (Test-Path -LiteralPath $MapPath)) { Stop-Run ('map not found: ' + $MapPath) 1 }
$all = @(Import-Csv -LiteralPath $MapPath -Encoding UTF8)
if ($all.Count -eq 0) { Stop-Run 'map is empty' 1 }

$writing = ($Apply -and -not $Verify)
$Script:Mode = 'plan'
if ($Verify -and $Transfer) { $Script:Mode = 'verify-transfer' }
elseif ($Verify) { $Script:Mode = 'verify' }
elseif ($Transfer -and $Apply) { $Script:Mode = 'transfer-apply' }
elseif ($Transfer) { $Script:Mode = 'transfer-plan' }
elseif ($Rollback -and $Apply) { $Script:Mode = 'rollback-apply' }
elseif ($Rollback) { $Script:Mode = 'rollback-plan' }
elseif ($Apply) { $Script:Mode = 'apply' }

# Who holds the repos for the read and write calls of this run.
$Holder = $Owner
if ($Transfer -and $Verify) { $Holder = $Org }

if ($Batch -eq 'all') { $rows = $all } else { $rows = @($all | Where-Object { $_.batch -ieq $Batch }) }
if ($rows.Count -eq 0) { Stop-Run ('no rows for batch ' + $Batch) 1 }
if ($writing) {
    if ($Batch -eq 'all') { Stop-Run 'writing needs one batch id, for example -Batch AR1' 1 }
    if ($Batch -notmatch '^AR\d+$') { Stop-Run ('batch ' + $Batch + ' is not an archive batch') 1 }
}

# ---------- check the map ----------
$problems = New-Object System.Collections.Generic.List[string]
$seen = @{}
foreach ($m in $rows) {
    $who = $m.old_name
    if (-not (Test-SafeName $m.old_name)) { $problems.Add("$who : bad old_name (letters, digits, dot, underscore, hyphen only)") }
    if (-not (Test-SafeName $m.new_name)) { $problems.Add("$who : bad new_name") }
    if (-not $m.new_name.StartsWith($Prefix)) { $problems.Add("$who : new_name must start with $Prefix") }
    if ($m.new_name.Length -gt 100) { $problems.Add("$who : new_name over 100 characters") }
    if ($m.new_name.Substring([Math]::Min($Prefix.Length, $m.new_name.Length)).StartsWith($Prefix)) { $problems.Add("$who : new_name doubles the prefix") }
    if ($m.new_name -match '(?i)RETIRED-') { $problems.Add("$who : new_name still holds RETIRED-") }
    $key = $m.new_name.ToLowerInvariant()
    if ($seen.ContainsKey($key)) { $problems.Add("$who : duplicate new_name") }
    $seen[$key] = $true
    if (-not $m.new_description.StartsWith($DescPrefix)) { $problems.Add("$who : new_description must start with '$DescPrefix'") }
    if ($m.new_description.Length -gt $MaxDesc) { $problems.Add("$who : new_description over $MaxDesc characters") }
    $t = Split-Topics $m.new_topics
    if ($t.Count -gt 20) { $problems.Add("$who : more than 20 topics") }
    foreach ($need in @('archived', 'do-not-use', 'stats-only')) {
        if ($t -cnotcontains $need) { $problems.Add("$who : topics need $need") }
    }
    if (@($t | Where-Object { $_ -cmatch '^origin-\d{4}$' }).Count -ne 1) { $problems.Add("$who : topics need exactly one origin-<year>") }
    foreach ($x in $t) { if ($x -cnotmatch '^[a-z0-9][a-z0-9-]{0,49}$') { $problems.Add("$who : bad topic '$x'") } }
    foreach ($x in (Split-Topics $m.old_topics)) { if ($x -cnotmatch '^[a-z0-9][a-z0-9-]{0,49}$') { $problems.Add("$who : bad old topic '$x'") } }
    if (@('go', 'clear', 'keep', 'skip', '') -cnotcontains $m.decision) { $problems.Add("$who : decision must be go, clear, keep, skip or blank") }
}
if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host ('  map error: ' + $_) }
    Stop-Run ('map failed checks (' + $problems.Count + '); nothing was sent') 1
}

$doRows = @($rows | Where-Object { @('go', 'clear', 'keep') -ccontains $_.decision })
$skipRows = @($rows | Where-Object { @('go', 'clear', 'keep') -cnotcontains $_.decision })
# go and clear clear the homepage. keep leaves it (a live site still uses it; owner decision).
function Test-ClearsHomepage { param($M) return (@('go', 'clear') -ccontains $M.decision) }

# The typed phrase: a verb, the batch id, and ROLLBACK for a rollback.
function Get-Phrase {
    if ($Transfer) { return ('TRANSFER {0}' -f $Batch.ToUpper()) }
    if ($Rollback) { return ('APPLY {0} ROLLBACK' -f $Batch.ToUpper()) }
    return ('APPLY {0}' -f $Batch.ToUpper())
}
function Get-VercelPhrase { return ('VERCEL DISCONNECTED {0}' -f $Batch.ToUpper()) }

# ---------- print the plan ----------
Write-Host ('Mode: ' + $Script:Mode + '   Owner: ' + $Owner + '   Org: ' + $Org + '   Batch: ' + $Batch + '   Repos to act on: ' + $doRows.Count + '   Skipped: ' + $skipRows.Count)
foreach ($m in $doRows) {
    $steps = @()
    if ($Transfer) {
        $steps += ('move ' + $m.new_name + ' from ' + $Owner + ' to ' + $Org)
        $steps += 'set status=archived if the org has that property'
        Write-Host ('  [{0}] {1} : {2}' -f $m.batch, $m.new_name, ($steps -join ', '))
    }
    elseif ($Rollback) {
        $steps += 'unarchive'
        if ($m.old_name -cne $m.new_name) { $steps += ('rename back to ' + $m.old_name) }
        $steps += 'restore description'
        $steps += 'restore topics'
        if ((Test-ClearsHomepage $m) -and $m.old_homepage) { $steps += 'restore homepage' }
        $steps += 'archive'
        Write-Host ('  [{0}] {1} -> {2} : {3}  (Actions stays off)' -f $m.batch, $m.new_name, $m.old_name, ($steps -join ', '))
    }
    else {
        $steps += 'unarchive'
        if ($m.old_name -cne $m.new_name) { $steps += ('rename to ' + $m.new_name) }
        $steps += 'description'
        $steps += 'topics'
        if ((Test-ClearsHomepage $m) -and $m.old_homepage) { $steps += 'clear homepage' }
        $steps += 'Actions off'
        $steps += 'archive'
        $note = ''
        if ($m.has_pages -eq 'True') { $note += '   BLOCKED until Pages is unpublished (owner step)' }
        if ($m.bot_deploy -eq 'True') { $note += '   Vercel: disconnect the project first' }
        if ($m.hooks_count -ne '0' -and $m.hooks_count -ne '') { $note += ('   webhooks: ' + $m.hooks_count + ' (owner removes)') }
        Write-Host ('  [{0}] {1} : {2}{3}' -f $m.batch, $m.old_name, ($steps -join ', '), $note)
    }
}
foreach ($m in $skipRows) {
    $why = 'decision blank'
    if ($m.decision) { $why = 'decision ' + $m.decision }
    $sg = ''
    if ($m.suggested) { $sg = ' [suggested: ' + $m.suggested + ']' }
    Write-Host ('  [{0}] {1} : SKIPPED ({2}){3} {4}' -f $m.batch, $m.old_name, $why, $sg, $m.hold_reason)
}

# ---------- dry run ends here ----------
$needVercel = ((-not $Transfer) -and (-not $Rollback) -and (@($doRows | Where-Object { $_.bot_deploy -eq 'True' }).Count -gt 0))
if (-not $writing -and -not $Verify) {
    Write-Host ''
    Write-Host 'Plan only. No network call was made and nothing was sent.'
    if ($Batch -ne 'all' -and $Batch -match '^AR\d+$' -and $doRows.Count -gt 0) {
        Write-Host ('To write, add -Apply and type exactly: ' + (Get-Phrase))
        if ($needVercel) { Write-Host ('This batch has Vercel-linked repos. You are then asked to type: ' + (Get-VercelPhrase)) }
    }
    if ($Transfer) { Write-Host ('-Apply refuses unless the org ' + $Org + ' exists and you own it.') }
    if ($skipRows.Count -gt 0) { Write-Host 'Skipped rows need a decision (go, clear or keep) in the map before they can run.' }
    exit 0
}

# ---------- auth ----------
$auth = Invoke-Gh @('auth', 'status')
if ($auth.Text -notmatch 'Logged in') { Stop-Run 'gh is not logged in (run gh auth login)' 1 }

# ---------- log file ----------
if (-not $LogPath) {
    $base = $env:LOCALAPPDATA
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    $dir = Join-Path $base 'archive-repos'
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    $LogPath = Join-Path $dir ('run-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.ndjson')
}
$Script:LogFile = $LogPath
Write-Host ('Log: ' + $LogPath)

# ---------- read-back ----------
function Test-Repo {
    param($M, [bool]$Back, [string]$Who)
    if ($Back) { $expName = $M.old_name; $expDesc = $M.old_description; $expTop = Split-Topics $M.old_topics }
    else { $expName = $M.new_name; $expDesc = $M.new_description; $expTop = Split-Topics $M.new_topics }
    $g = Get-Repo $expName $Who
    if (-not $g.Found) { return [pscustomobject]@{ Pass = $false; Detail = ('not found as ' + $expName + ' under ' + $Who + ' (HTTP ' + $g.Http + ')') } }
    $d = $g.Data
    $bad = @()
    if ($d.name -cne $expName) { $bad += 'name' }
    if (-not $d.archived) { $bad += 'not archived' }
    if ((Get-NormText $d.description) -cne (Get-NormText $expDesc)) { $bad += 'description' }
    if (-not (Test-SameSet @($d.topics) $expTop)) { $bad += 'topics' }
    if (-not $Back -and (Test-ClearsHomepage $M) -and "$($d.homepage)") { $bad += 'homepage not cleared' }
    if ($Back -and (Test-ClearsHomepage $M) -and "$($d.homepage)" -cne $M.old_homepage) { $bad += 'homepage not restored' }
    $warn = ''
    if ($d.has_pages) { $warn += ' (WARN: Pages still published)' }
    if (-not $Back) {
        $act = Get-ActionsEnabled $expName $Who
        if ($act -eq $true) { $bad += 'Actions still on' }
        elseif ($null -eq $act) { $warn += ' (WARN: Actions state unreadable)' }
    }
    if ($bad.Count -gt 0) { return [pscustomobject]@{ Pass = $false; Detail = ('mismatch: ' + ($bad -join ', ') + $warn) } }
    return [pscustomobject]@{ Pass = $true; Detail = ('matches the map' + $warn) }
}

if ($Verify) {
    $fail = 0
    foreach ($m in $doRows) {
        $Script:CurBatch = $m.batch
        $res = Test-Repo $m $Rollback.IsPresent $Holder
        $tag = 'PASS'
        if (-not $res.Pass) { $tag = 'FAIL'; $fail++ }
        $shown = $m.new_name
        if ($Rollback) { $shown = $m.old_name }
        Write-Host ('  {0} {1} : {2}' -f $tag, $shown, $res.Detail)
        Write-Log $shown 'verify' $res.Pass '' $res.Detail
        Start-Sleep -Milliseconds 300
    }
    Write-Host ('Verify done. Failures: ' + $fail)
    if ($fail -gt 0) { exit 4 } else { exit 0 }
}

# ---------- preflight (reads only) ----------
$phrase = Get-Phrase
if ($Transfer) {
    # The org must exist and you must own it. GitHub has no API to create an org.
    $o = Invoke-Gh @('api', ('orgs/{0}' -f $Org))
    if ($o.Code -ne 0) {
        if ($o.Http -eq '404') { Stop-Run ('the org ' + $Org + ' does not exist. Create it by hand first (docs/archive.md, Layer 1). Nothing was sent.') 1 }
        Stop-Run ('HTTP ' + $o.Http + ' on read of org ' + $Org) 2
    }
    $mem = Invoke-Gh @('api', ('user/memberships/orgs/{0}' -f $Org))
    $isOwner = $false
    if ($mem.Code -eq 0) {
        $mj = $mem.Text | ConvertFrom-Json
        if ($mj.role -ceq 'admin' -and $mj.state -ceq 'active') { $isOwner = $true }
    }
    if (-not $isOwner) { Stop-Run ('you are not an active owner of ' + $Org + ' (verify: gh api user/memberships/orgs/' + $Org + '). Nothing was sent.') 1 }
    Write-Host ('Org ' + $Org + ' exists and you own it.')
    foreach ($m in $doRows) {
        $here = Get-Repo $m.new_name $Owner
        $there = Get-Repo $m.new_name $Org
        if (-not $here.Found -and -not $there.Found) { $problems.Add($m.new_name + ' : not found under ' + $Owner + ' or ' + $Org + ' (rename it first)') }
        elseif ($here.Found -and -not $here.Data.archived) { $problems.Add($m.new_name + ' : not archived; run the rename batch first') }
        Start-Sleep -Milliseconds 300
    }
}
elseif (-not $Rollback) {
    foreach ($m in $doRows) {
        $g = Get-Repo $m.old_name $Owner
        if (-not $g.Found -and $m.old_name -cne $m.new_name) { $g = Get-Repo $m.new_name $Owner }
        if (-not $g.Found) { $problems.Add($m.old_name + ' : not found under ' + $Owner + ' as old or new name') }
        elseif ($g.Data.has_pages) { $problems.Add($m.old_name + ' : Pages is published; unpublish it first (owner step)') }
        Start-Sleep -Milliseconds 300
    }
}
if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Host ('  preflight: ' + $_) }
    Stop-Run ('preflight failed (' + $problems.Count + '); nothing was written') 1
}

# ---------- confirm ----------
Write-Host ''
Write-Host 'This will WRITE to GitHub. It never deletes anything. Check the plan above.'
Write-Host ('Type exactly: ' + $phrase)
$typed = Read-Host 'Confirm'
if ($typed -cne $phrase) { Stop-Run 'confirmation did not match; nothing was sent' 1 }
if ($needVercel) {
    Write-Host ('Some repos here are linked to Vercel. Disconnect each project in Vercel first, then type: ' + (Get-VercelPhrase))
    $typed2 = Read-Host 'Confirm Vercel'
    if ($typed2 -cne (Get-VercelPhrase)) { Stop-Run 'Vercel confirmation did not match; nothing was sent' 1 }
}
$Script:CurBatch = $Batch.ToUpper()
Write-Log '' 'confirmed' $true '' $phrase

# ---------- transfer ----------
if ($Transfer) {
    $propOk = $false
    $sch = Invoke-Gh @('api', ('orgs/{0}/properties/schema' -f $Org))
    if ($sch.Code -eq 0) {
        foreach ($p in ($sch.Text | ConvertFrom-Json)) { if ($p.property_name -ceq 'status') { $propOk = $true } }
    }
    if ($propOk) { Write-Host 'Org has a status property; it will be set to archived.' }
    else { Write-Host 'Org has no status property (or it cannot be read); that step is skipped.' }
    $moved = 0
    foreach ($m in $doRows) {
        $Script:CurBatch = $m.batch
        Write-Host ''
        Write-Host ('[{0}] {1} : {2} -> {3}' -f $m.batch, $m.new_name, $Owner, $Org)
        $there = Get-Repo $m.new_name $Org
        if ($there.Found) { Write-Host '    resume: already in the org' }
        else {
            Send-Write $m.new_name 'transfer' 'POST' ('repos/{0}/{1}/transfer' -f $Owner, $m.new_name) (@{ new_owner = $Org } | ConvertTo-Json -Compress)
            $tries = 0
            while (-not $there.Found -and $tries -lt 6) {
                Start-Sleep -Seconds $PauseSeconds
                $there = Get-Repo $m.new_name $Org
                $tries++
            }
            if (-not $there.Found) { Stop-Run ('transfer of ' + $m.new_name + ' was accepted but the repo is not yet under ' + $Org + '. Wait, then rerun the same batch (it resumes).') 3 }
        }
        if ($propOk) {
            $pb = '{"properties":[{"property_name":"status","value":"archived"}]}'
            $pr = Invoke-Gh @('api', '-X', 'PATCH', ('repos/{0}/{1}/properties/values' -f $Org, $m.new_name)) $pb
            Write-Log $m.new_name 'property' ($pr.Code -eq 0) $pr.Http $pb
            if ($pr.Code -eq 0) { Write-Host '    ok  status=archived' } else { Write-Host ('    warn: property not set (HTTP ' + $pr.Http + ')') }
            Start-Sleep -Seconds $PauseSeconds
        }
        $res = Test-Repo $m $false $Org
        if ($res.Pass) { Write-Host ('    PASS read-back: ' + $res.Detail) }
        else { Write-Host ('    FAIL read-back: ' + $res.Detail) }
        Write-Log $m.new_name 'readback' $res.Pass '' $res.Detail
        if (-not $res.Pass) { Stop-Run ('read-back failed on ' + $m.new_name + '; fix it before the next repo') 4 }
        $moved++
    }
    Write-Host ''
    Write-Host ('Transfer batch ' + $Batch + ' finished. Repos moved: ' + $moved + '. Skipped: ' + $skipRows.Count + '.')
    Write-Host ('Log: ' + $LogPath)
    exit 0
}

# ---------- apply or rollback ----------
$done = 0
foreach ($m in $doRows) {
    $Script:CurBatch = $m.batch
    if ($Rollback) { $fromName = $m.new_name; $toName = $m.old_name; $toDesc = $m.old_description; $toTop = Split-Topics $m.old_topics }
    else { $fromName = $m.old_name; $toName = $m.new_name; $toDesc = $m.new_description; $toTop = Split-Topics $m.new_topics }

    Write-Host ''
    Write-Host ('[{0}] {1} -> {2}' -f $m.batch, $fromName, $toName)
    $g = Resolve-Repo $fromName $toName $Owner
    if (-not $g.Found) { Stop-Run ('repo not found under ' + $Owner + ': ' + $fromName + ' or ' + $toName) 3 }
    $cur = $g.Name
    if ($fromName -cne $toName -and $cur -ceq $toName) { Write-Host '    resume: already renamed' }
    $d = $g.Data
    $before = @{ id = $d.id; name = $d.name; archived = $d.archived; description = "$($d.description)"; homepage = "$($d.homepage)"; topics = (@($d.topics) -join ';') } | ConvertTo-Json -Compress
    Write-Log $cur 'before' $true '' $before

    if ($d.archived) { Send-Write $cur 'unarchive' 'PATCH' ('repos/{0}/{1}' -f $Owner, $cur) '{"archived":false}' }

    if ($cur -cne $toName) {
        Send-Write $cur 'rename' 'PATCH' ('repos/{0}/{1}' -f $Owner, $cur) (@{ name = $toName } | ConvertTo-Json -Compress)
        $cur = $toName
    }

    if ((Get-NormText $d.description) -cne (Get-NormText $toDesc)) {
        Send-Write $cur 'description' 'PATCH' ('repos/{0}/{1}' -f $Owner, $cur) (@{ description = $toDesc } | ConvertTo-Json -Compress)
    }
    else { Write-Host '    skip description (already set)' }

    if (-not (Test-SameSet @($d.topics) $toTop)) {
        Send-Write $cur 'topics' 'PUT' ('repos/{0}/{1}/topics' -f $Owner, $cur) (ConvertTo-TopicJson $toTop)
    }
    else { Write-Host '    skip topics (already set)' }

    if (-not $Rollback -and (Test-ClearsHomepage $m) -and "$($d.homepage)") {
        Send-Write $cur 'homepage' 'PATCH' ('repos/{0}/{1}' -f $Owner, $cur) '{"homepage":""}'
    }
    if ($Rollback -and (Test-ClearsHomepage $m) -and $m.old_homepage -and "$($d.homepage)" -cne $m.old_homepage) {
        Send-Write $cur 'homepage' 'PATCH' ('repos/{0}/{1}' -f $Owner, $cur) (@{ homepage = $m.old_homepage } | ConvertTo-Json -Compress)
    }

    if (-not $Rollback) {
        $act = Get-ActionsEnabled $cur $Owner
        if ($act -ne $false) { Send-Write $cur 'actions-off' 'PUT' ('repos/{0}/{1}/actions/permissions' -f $Owner, $cur) '{"enabled":false}' }
        else { Write-Host '    skip Actions (already off)' }
    }

    Send-Write $cur 'archive' 'PATCH' ('repos/{0}/{1}' -f $Owner, $cur) '{"archived":true}'

    $res = Test-Repo $m $Rollback.IsPresent $Owner
    if ($res.Pass) { Write-Host ('    PASS read-back: ' + $res.Detail) }
    else { Write-Host ('    FAIL read-back: ' + $res.Detail) }
    Write-Log $cur 'readback' $res.Pass '' $res.Detail
    if (-not $res.Pass) { Stop-Run ('read-back failed on ' + $toName + '; fix it before the next repo') 4 }
    $done++
}

Write-Host ''
Write-Host ('Batch ' + $Batch + ' finished. Repos done: ' + $done + '. Skipped: ' + $skipRows.Count + '.')
Write-Host ('Log: ' + $LogPath)
exit 0
