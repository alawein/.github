$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../repo-sweep.ps1')

function Assert-True($Condition, [string]$Name) { if (-not $Condition) { throw "FAIL: $Name" } }
function Assert-Match($Lines, [string]$Pattern, [string]$Name) {
  if (-not (@($Lines) | Where-Object { $_ -match $Pattern })) { throw "FAIL: $Name (no line matches '$Pattern')`n$(@($Lines) -join "`n")" }
}
function Assert-NoMatch($Lines, [string]$Pattern, [string]$Name) {
  if (@($Lines) | Where-Object { $_ -match $Pattern }) { throw "FAIL: $Name (a line matches '$Pattern')`n$(@($Lines) -join "`n")" }
}

function G([string]$Dir, [string[]]$GitArgs) {
  $out = & git -C $Dir @GitArgs 2>&1
  if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed in ${Dir}: $out" }
  return $out
}
function Add-Commit([string]$Dir, [string]$File, [int]$DaysAgo = 0) {
  Set-Content -LiteralPath (Join-Path $Dir $File) -Value ([guid]::NewGuid().ToString())
  G $Dir @('add', $File) | Out-Null
  if ($DaysAgo -gt 0) { $env:GIT_COMMITTER_DATE = "$([DateTimeOffset]::UtcNow.AddDays(-$DaysAgo).ToUnixTimeSeconds()) +0000"; $env:GIT_AUTHOR_DATE = $env:GIT_COMMITTER_DATE }
  try { G $Dir @('commit', '-q', '-m', "add $File") | Out-Null }
  finally { Remove-Item Env:GIT_COMMITTER_DATE, Env:GIT_AUTHOR_DATE -ErrorAction SilentlyContinue }
}
function New-TestRepo([string]$Root, [string]$Owner, [string]$Name) {
  $dir = Join-Path (Join-Path $Root $Owner) $Name
  New-Item -ItemType Directory -Path $dir -Force | Out-Null
  & git -C $dir init -q -b main 2>&1 | Out-Null
  Add-Commit $dir 'README.md'
  G $dir @('remote', 'add', 'origin', "https://github.com/$Owner/$Name.git") | Out-Null
  G $dir @('update-ref', 'refs/remotes/origin/main', 'HEAD') | Out-Null
  return $dir
}
function Branch-Tip([string]$Dir, [string]$Branch) { return (G $Dir @('rev-parse', $Branch) | Select-Object -First 1) }
function Branch-Exists([string]$Dir, [string]$Branch) { & git -C $Dir rev-parse --verify -q "refs/heads/$Branch" *> $null; return ($LASTEXITCODE -eq 0) }

# Plain, signing-free, identity-fixed git for the temp repos.
$saved = @{}
foreach ($k in 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL', 'GIT_CONFIG_COUNT', 'GIT_CONFIG_KEY_0', 'GIT_CONFIG_VALUE_0') { $saved[$k] = [Environment]::GetEnvironmentVariable($k) }
$env:GIT_AUTHOR_NAME = 'Test'; $env:GIT_COMMITTER_NAME = 'Test'
$env:GIT_AUTHOR_EMAIL = 'test@example.test'; $env:GIT_COMMITTER_EMAIL = 'test@example.test'
$env:GIT_CONFIG_COUNT = '1'; $env:GIT_CONFIG_KEY_0 = 'commit.gpgsign'; $env:GIT_CONFIG_VALUE_0 = 'false'

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("repo-sweep-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  # ---------- status ----------
  $root = Join-Path $tmp 'status'
  $clean = New-TestRepo $root 'acme' 'clean-repo'
  $dirty = New-TestRepo $root 'acme' 'dirty-repo'
  Set-Content -LiteralPath (Join-Path $dirty 'scratch.txt') -Value 'x'
  $ahead = New-TestRepo $root 'acme' 'ahead-repo'
  Add-Commit $ahead 'second.md'
  $topics = New-TestRepo $root 'acme' 'topics-repo'
  foreach ($t in @(@('feat/fresh', 0), @('feat/idle', 8), @('feat/old', 20), @('fix/extra', 1))) {
    G $topics @('switch', '-q', '-c', $t[0]) | Out-Null
    Add-Commit $topics ("$($t[0] -replace '/', '-').md") $t[1]
    G $topics @('switch', '-q', 'main') | Out-Null
  }
  $stashy = New-TestRepo $root 'acme' 'stash-repo'
  Set-Content -LiteralPath (Join-Path $stashy 'README.md') -Value 'changed'
  G $stashy @('stash', 'push', '-q') | Out-Null
  $wtRepo = New-TestRepo $root 'acme' 'wt-repo'
  $wtDir = Join-Path $tmp 'gone-worktree'
  G $wtRepo @('worktree', 'add', '-q', '-b', 'feat/wt', $wtDir) | Out-Null
  Remove-Item -LiteralPath $wtDir -Recurse -Force
  # A linked worktree sitting at owner level must not be scanned as its own repo.
  G $clean @('worktree', 'add', '-q', '-b', 'feat/linked', (Join-Path (Join-Path $root 'acme') 'linked')) | Out-Null

  $repos = Find-Repo -RootDir $root -Extra @()
  Assert-True ($repos.Count -eq 6) "scan finds 6 repos and skips the linked worktree (got $($repos.Count))"
  Assert-True (-not ($repos | Where-Object { (Split-Path $_ -Leaf) -eq 'linked' })) 'linked worktree is not a repo'

  # Offline by default: any gh call would blow up.
  function Invoke-Gh { throw 'status without -Online must not call gh' }
  $briefOut = @(Invoke-Status -Repos $repos -Brief -Stale 14 -Warn 7 -MaxTopics 3)
  Assert-Match $briefOut 'acme/dirty-repo: dirty on main: 1 paths' 'dirty trunk flagged'
  Assert-Match $briefOut 'acme/ahead-repo: main is 1 ahead, 0 behind origin' 'ahead flagged'
  Assert-Match $briefOut 'acme/topics-repo: branch feat/old is 20 days old' 'old branch flagged'
  Assert-Match $briefOut 'acme/topics-repo: branch feat/idle idle 8 days' 'idle branch warned'
  Assert-Match $briefOut 'acme/topics-repo: 4 topic branches \(max 3\)' 'too many topics flagged'
  Assert-Match $briefOut 'acme/stash-repo: 1 stash entries' 'stash flagged'
  Assert-Match $briefOut 'acme/wt-repo: worktree folder missing' 'missing worktree flagged'
  Assert-NoMatch $briefOut 'clean-repo' 'clean repo has no flag'
  Assert-NoMatch $briefOut 'feat/fresh' 'fresh branch not flagged'
  Assert-True ($briefOut.Count -le 12) 'brief stays within 12 lines'

  $full = @(Invoke-Status -Repos $repos -Stale 14 -Warn 7 -MaxTopics 3)
  Assert-Match $full 'acme/clean-repo  on=main trunk=main dirty=0 ahead/behind=0/0 topics=0 worktrees=1 stashes=0 remote=yes' 'full line for a clean repo'
  Assert-Match $full 'topic feat/old: 1 ahead, last commit 20 days ago' 'topic detail'

  # Status never changes anything.
  Assert-True ((G $dirty @('status', '--porcelain')).Count -eq 1) 'status left the dirty repo untouched'

  # -Online adds PR counts through the seam.
  function Get-OpenPrCount([string]$Slug) { if ($Slug -eq 'acme/clean-repo') { 2 } else { $null } }
  $onlineOut = @(Invoke-Status -Repos @($clean, $dirty) -Online -Stale 14 -Warn 7 -MaxTopics 3)
  Assert-Match $onlineOut 'acme/clean-repo .* prs=2' 'online PR count'
  Assert-Match $onlineOut 'acme/dirty-repo .* prs=\?' 'unqueryable PR count shows ?'

  # No flags at all gives one line.
  $quiet = @(Invoke-Status -Repos @($clean) -Brief -Stale 14 -Warn 7 -MaxTopics 3)
  Assert-True ($quiet.Count -eq 1 -and $quiet[0] -eq 'repo-sweep: no flags (1 repos)') "quiet brief line (got: $quiet)"

  # Brief output is capped at 12 lines with a count of the rest.
  $many = 1..14 | ForEach-Object { $r = New-TestRepo (Join-Path $tmp 'many') 'acme' "r$_"; Set-Content -LiteralPath (Join-Path $r 'x.txt') -Value 'x'; $r }
  $capped = @(Invoke-Status -Repos $many -Brief -Stale 14 -Warn 7 -MaxTopics 3)
  Assert-True ($capped.Count -eq 12) "brief capped at 12 (got $($capped.Count))"
  Assert-Match $capped '^\+3 more flags' 'overflow line'
  Write-Host 'PASS: status'

  # ---------- clean ----------
  $croot = Join-Path $tmp 'clean'
  $repo = New-TestRepo $croot 'acme' 'clean-me'
  function New-Topic([string]$Name, [switch]$NoCommit) {
    G $repo @('switch', '-q', '-c', $Name) | Out-Null
    if (-not $NoCommit) { Add-Commit $repo ("$($Name -replace '/', '-').md") }
    G $repo @('switch', '-q', 'main') | Out-Null
  }
  $wtRoot = Join-Path $tmp 'worktrees'
  New-Item -ItemType Directory -Path $wtRoot | Out-Null

  New-Topic 'feat/merged'
  G $repo @('worktree', 'add', '-q', (Join-Path $wtRoot 'merged'), 'feat/merged') | Out-Null
  New-Topic 'feat/merged-nowt'
  New-Topic 'feat/merged-dirty'
  G $repo @('worktree', 'add', '-q', (Join-Path $wtRoot 'dirty'), 'feat/merged-dirty') | Out-Null
  Set-Content -LiteralPath (Join-Path $wtRoot 'dirty/notes.txt') -Value 'keep me'
  New-Topic 'feat/merged-ignored'
  G $repo @('worktree', 'add', '-q', (Join-Path $wtRoot 'ignored'), 'feat/merged-ignored') | Out-Null
  Set-Content -LiteralPath (Join-Path $wtRoot 'ignored/.gitignore') -Value 'secret.env'
  G (Join-Path $wtRoot 'ignored') @('add', '.gitignore') | Out-Null
  G (Join-Path $wtRoot 'ignored') @('commit', '-q', '-m', 'ignore secret') | Out-Null
  Set-Content -LiteralPath (Join-Path $wtRoot 'ignored/secret.env') -Value 'TOKEN=not-real'
  New-Topic 'feat/moved-on'
  New-Topic 'feat/no-pr'
  New-Topic 'feat/closed-dup' -NoCommit
  New-Topic 'feat/closed-unique'
  New-Topic 'feat/no-query'
  New-Topic 'feat/current'
  G $repo @('switch', '-q', 'feat/current') | Out-Null

  $tipMerged = Branch-Tip $repo 'feat/merged'
  $script:Evidence = @{
    'feat/merged'         = @([pscustomobject]@{ Number = 1; State = 'MERGED'; HeadSha = $tipMerged })
    'feat/merged-nowt'    = @([pscustomobject]@{ Number = 2; State = 'MERGED'; HeadSha = (Branch-Tip $repo 'feat/merged-nowt') })
    'feat/merged-dirty'   = @([pscustomobject]@{ Number = 3; State = 'MERGED'; HeadSha = (Branch-Tip $repo 'feat/merged-dirty') })
    'feat/merged-ignored' = @([pscustomobject]@{ Number = 4; State = 'MERGED'; HeadSha = (Branch-Tip $repo 'feat/merged-ignored') })
    'feat/moved-on'       = @([pscustomobject]@{ Number = 5; State = 'MERGED'; HeadSha = ('0' * 40) })
    'feat/no-pr'          = @()
    'feat/closed-dup'     = @([pscustomobject]@{ Number = 6; State = 'CLOSED'; HeadSha = (Branch-Tip $repo 'feat/closed-dup') })
    'feat/closed-unique'  = @([pscustomobject]@{ Number = 7; State = 'CLOSED'; HeadSha = (Branch-Tip $repo 'feat/closed-unique') })
    'feat/current'        = @([pscustomobject]@{ Number = 8; State = 'MERGED'; HeadSha = (Branch-Tip $repo 'feat/current') })
  }
  $script:Archived = $false
  function Get-PrEvidence { param([string]$Slug, [string]$Branch) if ($Branch -eq 'feat/no-query') { return $null }; return , @($script:Evidence[$Branch]) }
  function Test-RepoArchived { param([string]$Slug) return $script:Archived }

  $before = @(G $repo @('for-each-ref', '--format=%(refname)', 'refs/heads'))
  $dry = @(Invoke-Clean -Repos @($repo))
  $after = @(G $repo @('for-each-ref', '--format=%(refname)', 'refs/heads'))
  Assert-True (($before -join ',') -eq ($after -join ',')) 'dry run changes nothing'
  Assert-True (Test-Path (Join-Path $wtRoot 'merged')) 'dry run keeps the worktree'
  Assert-Match $dry 'WOULD acme/clean-me feat/merged: remove worktree .* delete branch \(PR #1 merged' 'dry run plans merged branch with worktree'
  Assert-Match $dry 'WOULD acme/clean-me feat/merged-nowt: delete branch' 'dry run plans a branch without worktree'
  Assert-Match $dry 'summary: 3 branch\(es\) eligible' 'dry run summary'

  $run = @(Invoke-Clean -Repos @($repo) -Apply)
  Assert-Match $run 'DONE acme/clean-me feat/merged:' 'merged branch removed'
  Assert-True (-not (Branch-Exists $repo 'feat/merged')) 'feat/merged deleted'
  Assert-True (-not (Test-Path (Join-Path $wtRoot 'merged'))) 'clean worktree removed'
  Assert-True (-not (Branch-Exists $repo 'feat/merged-nowt')) 'branch without worktree deleted'
  Assert-True (-not (Branch-Exists $repo 'feat/closed-dup')) 'closed PR with no unique commits deleted'
  foreach ($keep in 'feat/merged-dirty', 'feat/merged-ignored', 'feat/moved-on', 'feat/no-pr', 'feat/closed-unique', 'feat/no-query', 'feat/current', 'main') {
    Assert-True (Branch-Exists $repo $keep) "$keep kept"
  }
  Assert-Match $run 'SKIP acme/clean-me feat/merged-dirty: worktree has 1 uncommitted or untracked paths' 'dirty worktree skipped'
  Assert-True ((Get-Content -LiteralPath (Join-Path $wtRoot 'dirty/notes.txt')) -eq 'keep me') 'untracked file survives'
  Assert-Match $run 'SKIP acme/clean-me feat/merged-ignored: worktree holds 1 ignored paths' 'ignored files block removal'
  Assert-True (Test-Path (Join-Path $wtRoot 'ignored/secret.env')) 'ignored file survives'
  Assert-Match $run 'SKIP acme/clean-me feat/moved-on: local tip differs' 'unpushed work skipped'
  Assert-Match $run 'SKIP acme/clean-me feat/no-pr: no merge evidence' 'no evidence skipped'
  Assert-Match $run 'SKIP acme/clean-me feat/closed-unique: closed PR but 1 unique commits' 'closed with unique work skipped'
  Assert-Match $run 'SKIP acme/clean-me feat/no-query: cannot query pull requests' 'gh failure skipped'
  Assert-Match $run 'SKIP acme/clean-me feat/current: checked out in the main folder' 'current branch skipped'

  # Archived repos and failed lookups are skipped before any branch is looked at.
  $script:Archived = $true
  $arch = @(Invoke-Clean -Repos @($repo) -Apply)
  Assert-Match $arch 'SKIP acme/clean-me: repository is archived' 'archived repo skipped'
  $script:Archived = $null
  $unk = @(Invoke-Clean -Repos @($repo) -Apply)
  Assert-Match $unk 'SKIP acme/clean-me: cannot query GitHub' 'unreachable repo skipped'
  Assert-True (Branch-Exists $repo 'feat/no-pr') 'skipped repos lose nothing'
  Write-Host 'PASS: clean'

  # ---------- the script file itself never forces or fetches ----------
  $src = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../repo-sweep.ps1') -Raw
  Assert-True ($src -notmatch "'--force'|'-f'|'fetch'|'prune'|'push'|'-X'") 'no force, fetch, prune, push or API write in the script'
  Write-Host 'PASS: repo-sweep tests'
}
finally {
  foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
  Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
