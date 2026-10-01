param(
  [string[]]$Roots,
  [string[]]$OldDomains = @()
)

$ErrorActionPreference = 'Stop'

# Add only reviewed historical records: expected repo origin, repo-relative file, full line, reason, and one occurrence.
$script:HistoricalExceptions = @()
$script:ExpectedOrigins = @(
  'https://github.com/alawein/.github',
  'https://github.com/alawein/alawein',
  'https://github.com/alawein/meshal-site',
  'https://github.com/alawein/career-engine'
)

function Get-HistoricalLines {
  param([string]$Repo, [string]$Path, [array]$Manifest)
  $lines = @()
  foreach ($item in $Manifest) {
    if ($item.Repo -cne $Repo -or $item.Path -cne $Path) { continue }
    if ([string]::IsNullOrWhiteSpace($item.Reason) -or $item.MaxOccurrences -ne 1 -or [string]::IsNullOrEmpty($item.Line)) {
      throw "Invalid historical exception for $Path"
    }
    if ($lines -ccontains $item.Line) { throw "Duplicate historical exception for $Path" }
    $lines += [string]$item.Line
  }
  return $lines
}

function Find-LiveReference {
  param([string]$Text, [string]$Path, [string[]]$HistoricalLines, [string[]]$OldDomains)
  $patterns = @(
    '(?i)github\.com/alawein(?:-archive)?/(?:ARCHIVE-|RETIRED-)[^\s)''"]+',
    '(?i)raw\.githubusercontent\.com/alawein(?:-archive)?/(?:ARCHIVE-|RETIRED-)[^\s)''"]+',
    '(?i)uses:\s*alawein(?:-archive)?/(?:ARCHIVE-|RETIRED-)[^\s]+',
    '(?i)(?<![\w/])alawein(?:-archive)?/(?:ARCHIVE-|RETIRED-)[\w.-]+'
  )
  foreach ($domain in $OldDomains) {
    if ($domain -notmatch '^[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$') { throw "Invalid old domain: $domain" }
    $patterns += ('(?i)https?://' + [regex]::Escape($domain) + '(?::[0-9]+)?(?=$|[/?#\s)>''"])')
  }
  $seenHistory = @{}
  $lineNo = 0
  foreach ($line in ($Text -split '\r?\n')) {
    $lineNo++
    if ($HistoricalLines -ccontains $line) {
      if ($seenHistory.ContainsKey($line)) { throw "Duplicate historical occurrence in $Path" }
      $seenHistory[$line] = $true
      continue
    }
    foreach ($pattern in $patterns) {
      if ($line -match $pattern) {
        [pscustomobject]@{ path=$Path; line=$lineNo; rule='retired-live-reference' }
        break
      }
    }
  }
  foreach ($allowed in $HistoricalLines) {
    if (-not $seenHistory.ContainsKey($allowed)) { throw "Historical exception missing in $Path" }
  }
}

function Test-LiveReferencePath {
  param([string]$Root, [string]$RelativePath)
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '^[a-zA-Z]:') { throw 'Absolute or empty path refused' }
  $normalized = $RelativePath.Replace('\', '/')
  $parts = $normalized.Split('/')
  if ($parts | Where-Object { $_ -eq '' -or $_ -eq '.' -or $_ -eq '..' }) { throw 'Traversal path refused' }
  if ($parts | Where-Object { $_ -match '^(?i:\.git|\.env.*|\.superpowers|\.vercel|assets?|data|copy|brand|baselines?|budgets?|redirects?|records|out|rules|vault)$' }) { throw 'Forbidden path refused' }
  if ([IO.Path]::GetFileName($normalized) -in @('copy.md','archive-rename-map.csv','brand-tokens.json','baseline.json','budgets.json','redirects.json')) { throw 'Forbidden file refused' }
  if ([IO.Path]::GetExtension($normalized) -notin @('.md','.markdown','.mdx','.txt','.yml','.yaml','.json','.toml','.html','.htm','.xml')) { throw 'Non-text path refused' }
  $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $normalized))
  if (-not $candidate.StartsWith($rootFull + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Path outside root refused' }
  $walk = $rootFull
  foreach ($part in $parts) {
    $walk = Join-Path $walk $part
    if (Test-Path -LiteralPath $walk) {
      $attributes = [IO.File]::GetAttributes($walk)
      if (($attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Symlink or reparse path refused' }
    }
  }
  return $true
}

function Read-LiveReferenceText {
  param([string]$Root, [string]$RelativePath)
  Test-LiveReferencePath -Root $Root -RelativePath $RelativePath | Out-Null
  $path = Join-Path $Root $RelativePath
  if (-not [IO.File]::Exists($path)) { throw "Unreadable mandatory input: $RelativePath" }
  try { return [IO.File]::ReadAllText($path) }
  catch { throw "Unreadable mandatory input: $RelativePath" }
}

function Invoke-LocalGit {
  param([string]$Root, [string]$Arguments)
  $start = New-Object Diagnostics.ProcessStartInfo
  $start.FileName = 'git'
  $start.Arguments = $Arguments
  $start.WorkingDirectory = $Root
  $start.UseShellExecute = $false
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $process = [Diagnostics.Process]::Start($start)
  $output = $process.StandardOutput.ReadToEnd()
  $errorText = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  if ($process.ExitCode -ne 0) { throw "Git input failed: $errorText" }
  return $output
}

function Invoke-LiveReferenceScan {
  param([string[]]$Roots, [string[]]$OldDomains)
  if ($null -eq $Roots -or $Roots.Length -eq 0) { throw 'At least one live repo root is required' }
  $findings = @()
  $scannedHub = $false
  foreach ($root in $Roots) {
    if ([string]::IsNullOrWhiteSpace($root)) { throw 'Empty live repo root refused' }
    $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\','/')
    if (-not [IO.Directory]::Exists($rootFull)) { throw "Missing root: $root" }
    if (([IO.File]::GetAttributes($rootFull) -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse root refused: $root" }
    $top = (Invoke-LocalGit -Root $rootFull -Arguments 'rev-parse --show-toplevel').Trim()
    if ([IO.Path]::GetFullPath($top).TrimEnd('\','/') -ine $rootFull) { throw "Nested or wrong repo root: $root" }
    $origin = (Invoke-LocalGit -Root $rootFull -Arguments 'remote get-url origin').Trim() -replace '\.git$', ''
    if ($script:ExpectedOrigins -notcontains $origin) { throw "Unexpected origin for $root" }
    if ($origin -ceq 'https://github.com/alawein/career-engine') { $scannedHub = $true }
    $tracked = (Invoke-LocalGit -Root $rootFull -Arguments 'ls-files -z --cached') -split "`0"
    foreach ($relative in $tracked) {
      if (-not $relative) { continue }
      $relative = $relative.Replace('\','/')
      try { Test-LiveReferencePath -Root $rootFull -RelativePath $relative | Out-Null }
      catch {
        if ($_.Exception.Message -match 'Non-text path refused|Forbidden path refused|Forbidden file refused') { continue }
        throw
      }
      $history = @(Get-HistoricalLines -Repo $origin -Path $relative -Manifest $script:HistoricalExceptions)
      $content = Read-LiveReferenceText -Root $rootFull -RelativePath $relative
      $findings += @(Find-LiveReference -Text $content -Path $relative -HistoricalLines $history -OldDomains $OldDomains)
    }
    Write-Host "SCAN: $origin ($(@($tracked | Where-Object { $_ }).Count) tracked paths)"
  }
  foreach ($finding in $findings) { Write-Host "FAIL: $($finding.path):$($finding.line) $($finding.rule)" }
  if ($findings.Count -gt 0) { return 4 }
  Write-Host 'PASS: no live retirement references in supplied roots'
  if (-not $scannedHub) { Write-Host 'UNKNOWN: hub not scanned; owner must run this guard there' }
  return 0
}

if ($MyInvocation.InvocationName -ne '.') {
  try { exit (Invoke-LiveReferenceScan -Roots $Roots -OldDomains $OldDomains) }
  catch { [Console]::Error.WriteLine("FAIL: $($_.Exception.Message)"); exit 2 }
}
