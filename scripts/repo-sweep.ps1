<#
.SYNOPSIS
  Show repo and branch hygiene across a folder of checkouts, and remove merged branches.

.DESCRIPTION
  status  Read-only. Offline unless -Online. Prints one block per repo, or with -Brief
          only the flags (at most 12 lines).
  clean   Dry run unless -Apply. Removes a local branch, and its clean linked worktree,
          only when a merged PR proves the work landed. Never fetches, prunes, forces,
          touches remote branches, or deletes ignored or untracked files.

  Examples:
    pwsh scripts/repo-sweep.ps1 status -Brief
    pwsh scripts/repo-sweep.ps1 clean            # dry run
    pwsh scripts/repo-sweep.ps1 clean -Apply
#>
param(
  [Parameter(Position = 0)][ValidateSet('status', 'clean')][string]$Command = 'status',
  [string]$Root,
  [string[]]$Path = @(),
  [switch]$Brief,
  [switch]$Online,
  [switch]$Apply,
  [int]$StaleDays = 14,
  [int]$WarnDays = 7,
  [int]$MaxTopics = 3
)

$ErrorActionPreference = 'Stop'
$env:GIT_TERMINAL_PROMPT = '0'
$env:GIT_OPTIONAL_LOCKS = '0'
$BriefMaxLines = 12

# ---------- helpers ----------

function Invoke-Git {
  # Returns output lines; the exit code is left in $LASTEXITCODE.
  param([string]$Repo, [string[]]$GitArgs)
  $out = & git -C $Repo @GitArgs 2>$null
  if ($null -ne $out) { $out }
}

function Get-RepoSlug([string]$Repo) {
  # owner/repo from the origin URL. The URL itself is never printed (it can carry a token).
  $url = (Invoke-Git $Repo @('remote', 'get-url', 'origin') | Select-Object -First 1)
  if ($LASTEXITCODE -ne 0 -or -not $url) { return $null }
  if ($url -match 'github\.com[:/]+([^/]+)/([^/]+?)(\.git)?/?$') { return "$($Matches[1])/$($Matches[2])" }
  return $null
}

function Find-Repo {
  param([string]$RootDir, [string[]]$Extra)
  $found = New-Object System.Collections.Generic.List[string]
  $test = {
    param($dir)
    $dot = Join-Path $dir '.git'
    if (Test-Path -LiteralPath $dot -PathType Container) { return $true }
    if (Test-Path -LiteralPath $dot -PathType Leaf) {
      # A .git file means a linked worktree or submodule: reported under its parent, not as a repo.
      $text = Get-Content -LiteralPath $dot -TotalCount 1
      if ($text -match '[/\\]worktrees[/\\]') { return $false }
      return $true
    }
    return $false
  }
  if ($RootDir -and (Test-Path -LiteralPath $RootDir -PathType Container)) {
    if (& $test $RootDir) { $found.Add((Resolve-Path -LiteralPath $RootDir).Path) }
    foreach ($owner in Get-ChildItem -LiteralPath $RootDir -Directory -Force -ErrorAction SilentlyContinue) {
      if ($owner.Name.StartsWith('.')) { continue }
      if (& $test $owner.FullName) { $found.Add($owner.FullName); continue }
      foreach ($child in Get-ChildItem -LiteralPath $owner.FullName -Directory -Force -ErrorAction SilentlyContinue) {
        if (& $test $child.FullName) { $found.Add($child.FullName) }
      }
    }
  }
  foreach ($p in $Extra) {
    if ($p -and (Test-Path -LiteralPath $p -PathType Container) -and (& $test $p)) { $found.Add((Resolve-Path -LiteralPath $p).Path) }
  }
  return @($found | Select-Object -Unique)
}

function Get-Trunk([string]$Repo) {
  foreach ($t in 'main', 'master') {
    Invoke-Git $Repo @('rev-parse', '--verify', '-q', "refs/heads/$t") | Out-Null
    if ($LASTEXITCODE -eq 0) { return $t }
  }
  foreach ($t in 'main', 'master') {
    Invoke-Git $Repo @('rev-parse', '--verify', '-q', "refs/remotes/origin/$t") | Out-Null
    if ($LASTEXITCODE -eq 0) { return $t }
  }
  return $null
}

function Get-Worktree([string]$Repo) {
  # Linked worktrees only (the first porcelain entry is the main checkout).
  $lines = Invoke-Git $Repo @('worktree', 'list', '--porcelain')
  $entries = New-Object System.Collections.Generic.List[object]
  $cur = $null
  foreach ($line in $lines) {
    if ($line -like 'worktree *') {
      if ($cur) { $entries.Add($cur) }
      $cur = [pscustomobject]@{ Path = $line.Substring(9); Branch = $null; Detached = $false; Prunable = $false }
    }
    elseif ($cur -and $line -like 'branch refs/heads/*') { $cur.Branch = $line.Substring(18) }
    elseif ($cur -and $line -eq 'detached') { $cur.Detached = $true }
    elseif ($cur -and $line -like 'prunable*') { $cur.Prunable = $true }
  }
  if ($cur) { $entries.Add($cur) }
  if ($entries.Count -le 1) { return @() }
  return @($entries | Select-Object -Skip 1)
}

function Get-RepoState {
  param([string]$Repo, [datetime]$Now)
  $name = $null
  $slug = Get-RepoSlug $Repo
  $name = if ($slug) { $slug } else { Split-Path $Repo -Leaf }
  $trunk = Get-Trunk $Repo
  $cur = (Invoke-Git $Repo @('rev-parse', '--abbrev-ref', 'HEAD') | Select-Object -First 1)
  if ($LASTEXITCODE -ne 0) { $cur = '(unborn)' }
  $dirty = @(Invoke-Git $Repo @('status', '--porcelain')).Where({ $_ }).Count
  $remotes = @(Invoke-Git $Repo @('remote')).Where({ $_ }).Count
  $ahead = 0; $behind = 0; $hasUpstream = $false
  if ($trunk -and $remotes -gt 0) {
    Invoke-Git $Repo @('rev-parse', '--verify', '-q', "refs/remotes/origin/$trunk") | Out-Null
    if ($LASTEXITCODE -eq 0) {
      $hasUpstream = $true
      $c = (Invoke-Git $Repo @('rev-list', '--left-right', '--count', "$trunk...origin/$trunk") | Select-Object -First 1) -split '\s+'
      if ($c.Count -ge 2) { $ahead = [int]$c[0]; $behind = [int]$c[1] }
    }
  }
  $topics = New-Object System.Collections.Generic.List[object]
  $refs = Invoke-Git $Repo @('for-each-ref', '--format=%(refname:short)%09%(objectname)%09%(committerdate:unix)', 'refs/heads')
  foreach ($r in $refs) {
    if (-not $r) { continue }
    $f = $r -split "`t"
    $b = $f[0]
    if ($b -eq $trunk) { continue }
    if ($trunk) {
      Invoke-Git $Repo @('merge-base', '--is-ancestor', $b, $trunk) | Out-Null
      if ($LASTEXITCODE -eq 0) { continue }   # already contained in trunk: nothing to track
    }
    $age = [int][math]::Floor(($Now - [DateTimeOffset]::FromUnixTimeSeconds([int64]$f[2]).UtcDateTime).TotalDays)
    $n = if ($trunk) { [int](Invoke-Git $Repo @('rev-list', '--count', "$trunk..$b") | Select-Object -First 1) } else { 0 }
    $topics.Add([pscustomobject]@{ Name = $b; Tip = $f[1]; AgeDays = $age; Ahead = $n })
  }
  $wt = @(Get-Worktree $Repo)
  $stash = @(Invoke-Git $Repo @('stash', 'list')).Where({ $_ }).Count
  return [pscustomobject]@{
    Repo = $Repo; Name = $name; Slug = $slug; Trunk = $trunk; Current = $cur; Dirty = $dirty
    Remotes = $remotes; HasUpstream = $hasUpstream; Ahead = $ahead; Behind = $behind
    Topics = $topics.ToArray(); Worktrees = $wt; Stashes = $stash; OpenPrs = $null
  }
}

function Get-Flag {
  param($State, [int]$Stale, [int]$Warn, [int]$MaxTopics)
  $flags = New-Object System.Collections.Generic.List[string]
  if (-not $State.Trunk) { $flags.Add('no main or master branch found') }
  if ($State.Trunk -and $State.Current -eq $State.Trunk -and $State.Dirty -gt 0) {
    $flags.Add("dirty on $($State.Trunk): $($State.Dirty) paths")
  }
  if ($State.HasUpstream -and ($State.Ahead -gt 0 -or $State.Behind -gt 0)) {
    $flags.Add("$($State.Trunk) is $($State.Ahead) ahead, $($State.Behind) behind origin")
  }
  foreach ($t in $State.Topics) {
    if ($t.AgeDays -ge $Stale) { $flags.Add("branch $($t.Name) is $($t.AgeDays) days old (limit $Stale)") }
    elseif ($t.AgeDays -ge $Warn) { $flags.Add("branch $($t.Name) idle $($t.AgeDays) days (warn at $Warn)") }
  }
  if ($State.Topics.Count -gt $MaxTopics) { $flags.Add("$($State.Topics.Count) topic branches (max $MaxTopics)") }
  if ($State.Stashes -gt 0) { $flags.Add("$($State.Stashes) stash entries") }
  foreach ($w in $State.Worktrees) {
    if ($w.Prunable -or -not (Test-Path -LiteralPath $w.Path)) { $flags.Add("worktree folder missing: $($w.Path)") }
  }
  return @($flags)
}

# ---------- GitHub seams (tests replace these two functions) ----------

function Invoke-Gh {
  $gh = if ($env:REPO_SWEEP_GH) { $env:REPO_SWEEP_GH } else { 'gh' }
  $out = & $gh @args 2>$null
  if ($LASTEXITCODE -ne 0) { return $null }
  return $out
}

function Get-PrEvidence {
  # Returns objects { Number; State ('MERGED'|'CLOSED'); HeadSha } for PRs from this branch name, or $null if gh failed.
  param([string]$Slug, [string]$Branch)
  $merged = Invoke-Gh pr list --repo $Slug --head $Branch --state merged --json 'number,headRefOid' --limit 10
  if ($null -eq $merged) { return $null }
  $closed = Invoke-Gh pr list --repo $Slug --head $Branch --state closed --json 'number,headRefOid' --limit 10
  if ($null -eq $closed) { return $null }
  $result = New-Object System.Collections.Generic.List[object]
  foreach ($p in @(($merged -join "`n") | ConvertFrom-Json)) { if ($p) { $result.Add([pscustomobject]@{ Number = $p.number; State = 'MERGED'; HeadSha = $p.headRefOid }) } }
  foreach ($p in @(($closed -join "`n") | ConvertFrom-Json)) { if ($p) { $result.Add([pscustomobject]@{ Number = $p.number; State = 'CLOSED'; HeadSha = $p.headRefOid }) } }
  return , @($result)
}

function Test-RepoArchived {
  # $true, $false, or $null when it cannot be queried.
  param([string]$Slug)
  $out = Invoke-Gh repo view $Slug --json isArchived --jq '.isArchived'
  if ($null -eq $out) { return $null }
  return (("$out").Trim() -eq 'true')
}

function Get-OpenPrCount([string]$Slug) {
  $out = Invoke-Gh pr list --repo $Slug --state open --json number --jq 'length'
  if ($null -eq $out) { return $null }
  return [int](("$out").Trim())
}

# ---------- commands ----------

function Invoke-Status {
  param([string[]]$Repos, [switch]$Brief, [switch]$Online, [int]$Stale, [int]$Warn, [int]$MaxTopics)
  $now = (Get-Date).ToUniversalTime()
  $all = foreach ($r in $Repos) {
    $s = Get-RepoState -Repo $r -Now $now
    if ($Online -and $s.Slug) { $s.OpenPrs = Get-OpenPrCount $s.Slug }
    $s
  }
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($s in $all) {
    foreach ($f in (Get-Flag -State $s -Stale $Stale -Warn $Warn -MaxTopics $MaxTopics)) { $lines.Add("$($s.Name): $f") }
  }
  if ($Brief) {
    if ($lines.Count -eq 0) { Write-Output "repo-sweep: no flags ($(@($all).Count) repos)"; return }
    if ($lines.Count -le $BriefMaxLines) { $lines | ForEach-Object { Write-Output $_ }; return }
    $lines | Select-Object -First ($BriefMaxLines - 1) | ForEach-Object { Write-Output $_ }
    Write-Output "+$($lines.Count - ($BriefMaxLines - 1)) more flags (run without -Brief)"
    return
  }
  foreach ($s in $all) {
    $up = if ($s.HasUpstream) { "$($s.Ahead)/$($s.Behind)" } else { 'n/a' }
    $pr = if ($Online) { " prs=$(if ($null -eq $s.OpenPrs) { '?' } else { $s.OpenPrs })" } else { '' }
    Write-Output ("{0}  on={1} trunk={2} dirty={3} ahead/behind={4} topics={5} worktrees={6} stashes={7} remote={8}{9}" -f `
        $s.Name, $s.Current, $(if ($s.Trunk) { $s.Trunk } else { 'none' }), $s.Dirty, $up, $s.Topics.Count, $s.Worktrees.Count, $s.Stashes, $(if ($s.Remotes -gt 0) { 'yes' } else { 'no' }), $pr)
    foreach ($t in $s.Topics) { Write-Output ("    topic {0}: {1} ahead, last commit {2} days ago" -f $t.Name, $t.Ahead, $t.AgeDays) }
    foreach ($f in (Get-Flag -State $s -Stale $Stale -Warn $Warn -MaxTopics $MaxTopics)) { Write-Output "    ! $f" }
  }
}

function Invoke-Clean {
  param([string[]]$Repos, [switch]$Apply)
  $failures = 0; $planned = 0; $skipped = 0
  $mode = if ($Apply) { 'APPLY' } else { 'DRY RUN' }
  Write-Output "repo-sweep clean ($mode)"
  foreach ($repo in $Repos) {
    $name = Get-RepoSlug $repo
    if (-not $name) { $name = Split-Path $repo -Leaf }
    $slug = Get-RepoSlug $repo
    $trunk = Get-Trunk $repo
    $cur = (Invoke-Git $repo @('rev-parse', '--abbrev-ref', 'HEAD') | Select-Object -First 1)
    $refs = @(Invoke-Git $repo @('for-each-ref', '--format=%(refname:short)%09%(objectname)', 'refs/heads')).Where({ $_ })
    $candidates = @($refs | ForEach-Object { $f = $_ -split "`t"; [pscustomobject]@{ Name = $f[0]; Tip = $f[1] } } | Where-Object { $_.Name -ne $trunk })
    if ($candidates.Count -eq 0) { continue }
    if (-not $trunk) { Write-Output "SKIP ${name}: no main or master branch"; $skipped++; continue }
    if (-not $slug) { Write-Output "SKIP ${name}: no GitHub origin"; $skipped++; continue }
    $archived = Test-RepoArchived $slug
    if ($null -eq $archived) { Write-Output "SKIP ${name}: cannot query GitHub"; $skipped++; continue }
    if ($archived) { Write-Output "SKIP ${name}: repository is archived"; $skipped++; continue }
    $wts = @(Get-Worktree $repo)
    foreach ($c in $candidates) {
      $b = $c.Name
      if ($b -eq $cur) { Write-Output "SKIP ${name} ${b}: checked out in the main folder"; $skipped++; continue }
      $evidence = Get-PrEvidence -Slug $slug -Branch $b
      if ($null -eq $evidence) { Write-Output "SKIP ${name} ${b}: cannot query pull requests"; $skipped++; continue }
      $why = $null
      $mergedMatch = @($evidence | Where-Object { $_.State -eq 'MERGED' -and $_.HeadSha -eq $c.Tip }) | Select-Object -First 1
      if ($mergedMatch) { $why = "PR #$($mergedMatch.Number) merged, head matches local tip" }
      elseif (@($evidence | Where-Object { $_.State -eq 'MERGED' }).Count -gt 0) {
        Write-Output "SKIP ${name} ${b}: local tip differs from the merged PR head (unpushed work)"; $skipped++; continue
      }
      else {
        $closed = @($evidence | Where-Object { $_.State -eq 'CLOSED' }) | Select-Object -First 1
        if ($closed) {
          $cherry = @(Invoke-Git $repo @('cherry', $trunk, $b)).Where({ $_ -like '+*' }).Count
          if ($cherry -eq 0) { $why = "PR #$($closed.Number) closed, no unique commits vs $trunk" }
          else { Write-Output "SKIP ${name} ${b}: closed PR but $cherry unique commits"; $skipped++; continue }
        }
        else { Write-Output "SKIP ${name} ${b}: no merge evidence"; $skipped++; continue }
      }
      $wt = $wts | Where-Object { $_.Branch -eq $b } | Select-Object -First 1
      if ($wt) {
        if (-not (Test-Path -LiteralPath $wt.Path)) { Write-Output "SKIP ${name} ${b}: worktree folder missing (git worktree prune is a separate step)"; $skipped++; continue }
        $d = @(Invoke-Git $wt.Path @('status', '--porcelain')).Where({ $_ }).Count
        if ($d -gt 0) { Write-Output "SKIP ${name} ${b}: worktree has $d uncommitted or untracked paths"; $skipped++; continue }
        # Removing a worktree deletes its ignored files too; this tool never does that.
        $ign = @(Invoke-Git $wt.Path @('status', '--porcelain', '--ignored')).Where({ $_ -like '!!*' }).Count
        if ($ign -gt 0) { Write-Output "SKIP ${name} ${b}: worktree holds $ign ignored paths, remove it by hand"; $skipped++; continue }
      }
      $planned++
      $action = if ($wt) { "remove worktree $($wt.Path), delete branch" } else { 'delete branch' }
      if (-not $Apply) { Write-Output "WOULD ${name} ${b}: $action ($why)"; continue }
      if ($wt) {
        Invoke-Git $repo @('worktree', 'remove', $wt.Path) | Out-Null
        if ($LASTEXITCODE -ne 0) { Write-Output "FAIL ${name} ${b}: git refused to remove the worktree"; $failures++; continue }
      }
      Invoke-Git $repo @('branch', '-D', $b) | Out-Null
      if ($LASTEXITCODE -ne 0) { Write-Output "FAIL ${name} ${b}: branch delete failed"; $failures++; continue }
      Write-Output "DONE ${name} ${b}: $action ($why)"
    }
  }
  Write-Output "summary: $planned branch(es) $(if ($Apply) { 'processed' } else { 'eligible' }), $skipped skipped, $failures failed"
  if ($failures -gt 0) { exit 1 }
}

# ---------- entry ----------

if ($MyInvocation.InvocationName -eq '.') { return }   # dot-sourced by tests

if (-not $Root) { $Root = Join-Path $HOME 'Desktop/GitHub' }
$repos = Find-Repo -RootDir $Root -Extra $Path
if ($repos.Count -eq 0) { Write-Output "repo-sweep: no repositories found under $Root"; exit 0 }
switch ($Command) {
  'status' { Invoke-Status -Repos $repos -Brief:$Brief -Online:$Online -Stale $StaleDays -Warn $WarnDays -MaxTopics $MaxTopics }
  'clean' { Invoke-Clean -Repos $repos -Apply:$Apply }
}
exit 0
