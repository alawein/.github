$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../check-live-references.ps1')

function Assert-Count($Actual, [int]$Expected, [string]$Name) {
  $count = @($Actual | Where-Object { $null -ne $_ }).Count
  if ($count -ne $Expected) { throw "$Name expected $Expected; got $count" }
}
function Assert-Rejected([scriptblock]$Action, [string]$Name) {
  $rejected = $false
  try { & $Action | Out-Null } catch { $rejected = $true }
  if (-not $rejected) { throw "$Name was accepted" }
}

$archived = '[Use this](https://github.com/alawein/ARCHIVE-example)'
$history = 'Historical: [old](https://github.com/alawein/ARCHIVE-example)'
Assert-Count (Find-LiveReference -Text $archived -Path 'README.md' -HistoricalLines @() -OldDomains @()) 1 'active archive URL'
Assert-Count (Find-LiveReference -Text $history -Path 'history.md' -HistoricalLines @($history) -OldDomains @()) 0 'exact history line'
$both = $history + "`n" + $archived
$found = @(Find-LiveReference -Text $both -Path 'history.md' -HistoricalLines @($history) -OldDomains @())
Assert-Count $found 1 'mixed history and active lines'
if ($found[0].line -ne 2 -or $found[0].path -ne 'history.md' -or $found[0].rule -ne 'retired-live-reference') { throw 'finding fields changed' }
if ((($found[0].PSObject.Properties.Name | Sort-Object) -join ',') -ne 'line,path,rule') { throw 'finding exposed extra fields' }
Assert-Rejected { Find-LiveReference -Text ($history + "`n" + $history) -Path 'history.md' -HistoricalLines @($history) -OldDomains @() } 'duplicate historical occurrence'
Assert-Count (Find-LiveReference -Text 'https://raw.githubusercontent.com/alawein/RETIRED-example/main/a.md' -Path 'README.md' -HistoricalLines @() -OldDomains @()) 1 'raw retired URL'
Assert-Count (Find-LiveReference -Text 'uses: alawein/ARCHIVE-example@v1' -Path '.github/workflows/ci.yml' -HistoricalLines @() -OldDomains @()) 1 'archived workflow pin'
Assert-Count (Find-LiveReference -Text 'https://old.example.test/page?x=1' -Path 'README.md' -HistoricalLines @() -OldDomains @('old.example.test')) 1 'old domain query URL'
Assert-Count (Find-LiveReference -Text 'https://notold.example.test/' -Path 'README.md' -HistoricalLines @() -OldDomains @('old.example.test')) 0 'domain boundary'
Assert-Count (Find-LiveReference -Text '[Old](https://old.example.test)' -Path 'README.md' -HistoricalLines @() -OldDomains @('old.example.test')) 1 'bare old domain Markdown link'
Assert-Count (Find-LiveReference -Text '<https://old.example.test>' -Path 'README.md' -HistoricalLines @() -OldDomains @('old.example.test')) 1 'bare old domain autolink'
Assert-Count (Find-LiveReference -Text '<a href="https://old.example.test">Old</a>' -Path 'README.html' -HistoricalLines @() -OldDomains @('old.example.test')) 1 'bare old domain quoted href'
Assert-Count (Find-LiveReference -Text "<a href='https://old.example.test'>Old</a>" -Path 'README.html' -HistoricalLines @() -OldDomains @('old.example.test')) 1 'single quoted href'
Assert-Count (Find-LiveReference -Text 'https://old.example.test:8443/path' -Path 'README.md' -HistoricalLines @() -OldDomains @('old.example.test')) 1 'old domain port and path'
Assert-Count (Find-LiveReference -Text 'https://old.example.test?x=1' -Path 'README.md' -HistoricalLines @() -OldDomains @('old.example.test')) 1 'bare old domain query'
Assert-Count (Find-LiveReference -Text 'https://old.example.test.evil/path' -Path 'README.md' -HistoricalLines @() -OldDomains @('old.example.test')) 0 'old domain suffix lookalike'
Assert-Count (Find-LiveReference -Text 'Pinned: alawein/ARCHIVE-example' -Path 'README.md' -HistoricalLines @() -OldDomains @()) 1 'archived repo pin'
Assert-Count (Find-LiveReference -Text '[Old](https://github.com/alawein-archive/ARCHIVE-example)' -Path 'README.md' -HistoricalLines @() -OldDomains @()) 1 'archive org URL'
Write-Host 'PASS: pure reference rules and exact historical occurrence'

$manifest = @(@{ Repo='https://github.com/alawein/.github'; Path='docs/history.md'; Line=$history; Reason='Reviewed migration record'; MaxOccurrences=1 })
Assert-Count (Get-HistoricalLines -Repo 'https://github.com/alawein/.github' -Path 'docs/history.md' -Manifest $manifest) 1 'reviewed file exception'
Assert-Count (Get-HistoricalLines -Repo 'https://github.com/alawein/.github' -Path 'README.md' -Manifest $manifest) 0 'exception file scope'
Assert-Count (Get-HistoricalLines -Repo 'https://github.com/alawein/alawein' -Path 'docs/history.md' -Manifest $manifest) 0 'exception repo scope'
Assert-Rejected { Get-HistoricalLines -Repo 'https://github.com/alawein/.github' -Path 'docs/history.md' -Manifest @(@{ Repo='https://github.com/alawein/.github'; Path='docs/history.md'; Line=$history; Reason=''; MaxOccurrences=1 }) } 'exception without reason'
Assert-Rejected { Get-HistoricalLines -Repo 'https://github.com/alawein/.github' -Path 'docs/history.md' -Manifest @(@{ Repo='https://github.com/alawein/.github'; Path='docs/history.md'; Line=$history; Reason='record'; MaxOccurrences=2 }) } 'exception count above one'
Write-Host 'PASS: historical manifest scope'

$guard = Join-Path (Split-Path -Parent $PSScriptRoot) 'check-live-references.ps1'
$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
function Invoke-GuardCli([string[]]$Arguments) {
  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = (& $pwsh -NoProfile -File $guard @Arguments 2>&1 | Out-String)
    $code = $LASTEXITCODE
  } finally { $ErrorActionPreference = $savedPreference }
  return [pscustomobject]@{ Output=$output; Code=$code }
}
$missingRoots = Invoke-GuardCli -Arguments @()
if ($missingRoots.Code -ne 2 -or $missingRoots.Output -match 'PASS:' -or $missingRoots.Output -notmatch 'At least one live repo root is required') { throw "omitted roots CLI was accepted: $($missingRoots.Output)" }
$guardLiteral = "'" + $guard.Replace("'", "''") + "'"
$expression = '& ' + $guardLiteral + " -Roots @(''); exit " + '$LASTEXITCODE'
$encodedExpression = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($expression))
$savedPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  $emptyRootOutput = (& $pwsh -NoProfile -EncodedCommand $encodedExpression 2>&1 | Out-String)
  $emptyRootCode = $LASTEXITCODE
} finally { $ErrorActionPreference = $savedPreference }
if ($emptyRootCode -ne 2 -or $emptyRootOutput -match 'PASS:') { throw "empty root CLI was accepted: $emptyRootOutput" }
Write-Host 'PASS: omitted and empty roots fail without success output'

$scratchParent = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.superpowers'
$scratch = Join-Path $scratchParent ('references-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
  New-Item -ItemType Directory -Path (Join-Path $scratch 'docs') | Out-Null
  Set-Content -LiteralPath (Join-Path $scratch 'docs/ok.md') -Value 'safe'
  foreach ($bad in @('../outside.md', '/absolute.md', '.git/config', '.env', 'docs/.env.local', 'assets/logo.svg', 'data/catalog.json', 'records/history.md', 'out/export.md', 'rules/policy.json', 'vault/notes.md', '.vercel/project.json', 'docs/archive-rename-map.csv', 'docs/copy.md')) {
    Assert-Rejected { Test-LiveReferencePath -Root $scratch -RelativePath $bad } "forbidden path $bad"
  }
  if (-not (Test-LiveReferencePath -Root $scratch -RelativePath 'docs/ok.md')) { throw 'safe doc rejected' }
  foreach ($liveDoc in @('docs/brand.md', 'docs/copywriting.md', 'docs/redirect-guide.md', 'docs/records.md')) {
    if (-not (Test-LiveReferencePath -Root $scratch -RelativePath $liveDoc)) { throw "ordinary live doc rejected: $liveDoc" }
  }
  Assert-Rejected { Read-LiveReferenceText -Root $scratch -RelativePath 'docs/missing.md' } 'unreadable mandatory input'
  $planted = Join-Path $scratch 'docs/brand.md'
  Set-Content -LiteralPath $planted -Value $archived
  Assert-Count (Find-LiveReference -Text (Read-LiveReferenceText -Root $scratch -RelativePath 'docs/brand.md') -Path 'docs/brand.md' -HistoricalLines @() -OldDomains @()) 1 'planted failure'
  & git -C $scratch init -q | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'scratch git init failed' }
  & git -C $scratch remote add origin 'https://github.com/alawein/.github.git'
  if ($LASTEXITCODE -ne 0) { throw 'scratch origin setup failed' }
  & git -C $scratch add -- docs/brand.md
  if ($LASTEXITCODE -ne 0) { throw 'scratch fixture tracking failed' }
  $failureOutput = (& $pwsh -NoProfile -File $guard -Roots $scratch 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 4 -or $failureOutput -notmatch 'docs/brand.md:1 retired-live-reference') { throw "planted CLI case did not fail as required: $failureOutput" }
  Set-Content -LiteralPath $planted -Value 'Live site: https://example.test/'
  Assert-Count (Find-LiveReference -Text (Read-LiveReferenceText -Root $scratch -RelativePath 'docs/brand.md') -Path 'docs/brand.md' -HistoricalLines @() -OldDomains @()) 0 'clean planted fixture'
  $cleanOutput = (& $pwsh -NoProfile -File $guard -Roots $scratch 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0 -or $cleanOutput -notmatch 'PASS: no live retirement references' -or $cleanOutput -notmatch 'UNKNOWN: hub not scanned') { throw "clean non-hub CLI case did not pass: $cleanOutput" }
  & git -C $scratch remote set-url origin 'https://github.com/alawein/career-engine.git'
  if ($LASTEXITCODE -ne 0) { throw 'scratch hub origin setup failed' }
  $hubOrigin = Invoke-GuardCli -Arguments @('-Roots', $scratch)
  if ($hubOrigin.Code -ne 0 -or $hubOrigin.Output -notmatch 'PASS: no live retirement references' -or $hubOrigin.Output -match 'UNKNOWN: hub not scanned') { throw "approved hub origin was rejected or marked unscanned: $($hubOrigin.Output)" }
  & git -C $scratch remote set-url origin 'https://github.com/alawein/unapproved.git'
  if ($LASTEXITCODE -ne 0) { throw 'scratch unapproved origin setup failed' }
  $wrongOrigin = Invoke-GuardCli -Arguments @('-Roots', $scratch)
  if ($wrongOrigin.Code -ne 2 -or $wrongOrigin.Output -notmatch 'Unexpected origin' -or $wrongOrigin.Output -match 'PASS:') { throw "unapproved origin was accepted: $($wrongOrigin.Output)" }
  Write-Host 'PASS: approved hub origin and unapproved origin rejection'
  Write-Host 'PASS: path safety, unreadable input, planted CLI failure and clean CLI fixture'
} finally {
  $resolvedScratch = [IO.Path]::GetFullPath($scratch)
  $resolvedParent = [IO.Path]::GetFullPath($scratchParent).TrimEnd('\','/')
  if (-not $resolvedScratch.StartsWith($resolvedParent + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolvedScratch) -notmatch '^references-test-[a-f0-9]{32}$') { throw 'scratch cleanup path refused' }
  Remove-Item -LiteralPath $scratch -Recurse -Force
}
