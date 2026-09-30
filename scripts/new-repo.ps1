<#
.SYNOPSIS
  Create a new local repo folder from a starter. Dry run by default.

.DESCRIPTION
  Copies a starter from templates\starters into <Path>\<Name>, fills the
  {{placeholders}} (including AGENTS.md, CLAUDE.md, and docs\lessons.md), and
  prints what to do next. It checks the name against the naming rules in
  docs\system\repos.md first, and stops if the name breaks one.
  Without -Create it writes nothing and only prints the plan.
  It never runs git and never makes a network call. The folder it writes
  must not exist yet, so it cannot overwrite anything.

.PARAMETER Name
  Repo name: lowercase words joined by hyphens, 3 to 30 characters. The suffix
  must match the class (-site, -docs or -kit, -lab). A tool has no suffix. The
  profile repo is named like the owner and uses class profile. A name that
  starts with ARCHIVE- is refused.

.PARAMETER Class
  profile, docs, tool, site, or lab. See docs\system\repos.md. Class archive
  has no starter and is refused.

.PARAMETER Language
  typescript (default) or python. Used by class tool only. A lab is Python and
  a site is Astro, so they ignore it.

.PARAMETER Description
  One plain sentence for the README and the package file. Letters, digits,
  spaces, and , . ; : ( ) ' ! ? / + - only. A placeholder sentence is used if
  you leave it out.

.PARAMETER DisplayName
  Name as it reads in the banner and page title, 28 characters at most.
  Default: the repo name in sentence case.

.PARAMETER Visibility
  private (default) or public. A private repo gets no LICENSE file. The
  profile repo is always public.

.PARAMETER Holder
  Name in the license line. Default: alawein.

.PARAMETER Path
  Parent folder for the new repo folder. Default: the current folder. It must
  be outside the kit folder.

.PARAMETER Create
  Write the files. Without it nothing is written.

.EXAMPLE
  .\new-repo.ps1 -Name label-sync -Class tool -Language python -Description "Sync GitHub labels from a file."
  .\new-repo.ps1 -Name label-sync -Class tool -Language python -Description "Sync GitHub labels from a file." -Create
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Name,
  [Parameter(Mandatory = $true)][ValidateSet('profile', 'docs', 'tool', 'site', 'lab', 'archive')][string]$Class,
  [ValidateSet('typescript', 'python')][string]$Language = 'typescript',
  [string]$Description,
  [string]$DisplayName,
  [ValidateSet('private', 'public')][string]$Visibility = 'private',
  [string]$Holder,
  [string]$Path = (Get-Location).Path,
  [switch]$Create
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Every repo and every shared workflow lives under this owner.
$Owner = 'alawein'

function Fail([string[]]$Messages) {
  foreach ($m in $Messages) { Write-Host ('new-repo: ' + $m) }
  exit 1
}

# ---------------------------------------------------------------- name rules
if ($Class -eq 'archive') { Fail @('Class archive has no starter. Retire a repo with scripts\archive-repos.ps1 (docs\archive.md).') }
if ($Name -cmatch '^ARCHIVE-') { Fail @('ARCHIVE- names are for retired repos only. Nothing is created for them.') }
$problems = @()
$isProfile = ($Class -eq 'profile')
if ($isProfile) { $Visibility = 'public' }
# The starter folder: profile and docs share one, a tool picks by language.
$starter = switch ($Class) {
  'profile' { 'docs' }
  'docs'    { 'docs' }
  'tool'    { $Language }
  'site'    { 'site' }
  'lab'     { 'lab' }
}

if ($Name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
  $problems += 'The name must be lowercase letters, digits, and single hyphens between words.'
}
if ($Name.Length -lt 3 -or $Name.Length -gt 30) {
  $problems += 'The name must be 3 to 30 characters.'
}
if (($Name -ceq $Owner) -and ($Class -ne 'profile')) {
  $problems += 'A repo named like the owner is the profile repo. Use class profile.'
}
if ($isProfile -and ($Name -cne $Owner)) {
  $problems += "The profile repo is named like the owner: $Owner."
}
if (-not $isProfile) {
  $banned = @('new', 'old', 'final', 'draft', 'wip', 'beta', 'alpha', 'tmp', 'temp', 'copy', 'backup', 'bak')
  foreach ($w in $Name.Split('-')) {
    if ($banned -contains $w) { $problems += "The word '$w' is a status or scratch word. Drop it." }
    if (($w -match '^v\d+$') -or ($w -match '^(19|20)\d\d$') -or ($w -match '^\d{6,8}$')) {
      $problems += "'$w' looks like a version or a date. Drop it."
    }
  }
  if ($Name.StartsWith($Owner + '-')) { $problems += 'Do not start the name with the owner.' }

  $suffixClass = @{ '-site' = 'site'; '-docs' = 'docs'; '-kit' = 'docs'; '-lab' = 'lab' }
  foreach ($s in $suffixClass.Keys) {
    if ($Name.EndsWith($s) -and ($suffixClass[$s] -ne $Class)) {
      $problems += "A name ending in $s is class $($suffixClass[$s]), not $Class."
    }
  }
  if ($Class -eq 'site' -and -not $Name.EndsWith('-site')) { $problems += 'A site name ends in -site.' }
  if ($Class -eq 'lab' -and -not $Name.EndsWith('-lab')) { $problems += 'A lab name ends in -lab.' }
  if ($Class -eq 'docs' -and -not ($Name.EndsWith('-docs') -or $Name.EndsWith('-kit'))) {
    $problems += 'A docs name ends in -docs or -kit (the profile repo is named like the owner).'
  }
}

$module = $Name.Replace('-', '_')
if (($starter -in @('python', 'lab')) -and ($module -match '^\d')) {
  $problems += 'A Python package name cannot start with a digit.'
}

# ---------------------------------------------------------------- text fields
$defaults = @{
  profile    = 'Who I am, selected work, and where to find me.'
  docs       = 'Notes and guides. Replace this with one plain sentence about what this repo covers.'
  typescript = 'A TypeScript library. Replace this with one plain sentence about what it does.'
  python     = 'A Python package and command line tool. Replace this with one plain sentence about what it does.'
  site       = 'A website built with Astro. Replace this with one plain sentence about what it shows.'
  lab        = 'An experiment. Replace this with one plain sentence about the question it asks.'
}
$descriptionGiven = -not [string]::IsNullOrWhiteSpace($Description)
if (-not $descriptionGiven) {
  $Description = $defaults[$starter]
  if ($isProfile) { $Description = $defaults['profile'] } elseif ($Class -eq 'docs') { $Description = $defaults['docs'] }
}
if (($Description.Length -gt 200) -or ($Description -notmatch "^[A-Za-z0-9 ,.;:()'!?/+-]+$")) {
  $problems += "The description must be 200 characters or fewer, using letters, digits, spaces, and , . ; : ( ) ' ! ? / + - only."
}

if ([string]::IsNullOrWhiteSpace($DisplayName)) {
  $DisplayName = $Name.Replace('-', ' ')
  if ($DisplayName.Length -gt 0) { $DisplayName = $DisplayName.Substring(0, 1).ToUpper() + $DisplayName.Substring(1) }
}
if ($DisplayName -notmatch '^[A-Za-z0-9 .+-]{1,28}$') {
  $problems += 'The display name must be 1 to 28 characters: letters, digits, spaces, and . + - only. Pass -DisplayName.'
}

if ([string]::IsNullOrWhiteSpace($Holder)) { $Holder = $Owner }
if ($Holder -notmatch '^[A-Za-z0-9 ._-]+$') { $problems += 'The license holder must use letters, digits, spaces, and . _ - only.' }

if ($problems.Count -gt 0) { Fail $problems }

# ---------------------------------------------------------------- paths
$kit = Split-Path -Parent $PSScriptRoot
$startersRoot = Join-Path $kit 'templates\starters'
$src = Join-Path $startersRoot $starter
if (-not (Test-Path -LiteralPath $src -PathType Container)) { Fail @("Starter not found: templates\starters\$starter") }
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { Fail @("The parent folder does not exist: $Path") }
$dest = Join-Path (Resolve-Path -LiteralPath $Path).Path $Name
if (Test-Path -LiteralPath $dest) { Fail @("The folder already exists, so nothing is written: $dest") }
if ($dest.StartsWith($kit.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  Fail @('The new folder would sit inside the kit. Pass -Path with a folder outside it.')
}

# ---------------------------------------------------------------- license
$licenseSource = Join-Path $src 'LICENSE'
$licenseId = ''
$licenseName = ''
if ($isProfile) {
  $licenseSource = ''
} elseif ($Class -eq 'docs') {
  if ($Name.EndsWith('-kit')) {
    $licenseSource = Join-Path $startersRoot 'typescript\LICENSE'
    $licenseId = 'MIT'; $licenseName = 'MIT'
  } else {
    $licenseId = 'CC-BY-4.0'; $licenseName = 'CC BY 4.0'
  }
} elseif ($Class -eq 'site') {
  $licenseSource = ''
} else {
  $licenseId = 'MIT'; $licenseName = 'MIT'
}
$hasLicense = ($Visibility -eq 'public') -and ($licenseSource -ne '') -and (Test-Path -LiteralPath $licenseSource)

if ($hasLicense) {
  if ($Class -eq 'lab') {
    $licenseSection = 'Code: MIT, see [LICENSE](LICENSE). Text and figures: CC BY 4.0. Data: CC0-1.0. A file that says otherwise wins for that file.'
  } else {
    $licenseSection = "$licenseName. See [LICENSE](LICENSE)."
  }
  $licenseNpm = $licenseId
  $licenseToml = "license = `"$licenseId`""
} else {
  $licenseSection = 'All rights reserved.'
  $licenseNpm = 'UNLICENSED'
  $licenseToml = 'classifiers = ["Private :: Do Not Upload"]'
}

$tokens = @{
  'name'            = $Name
  'display_name'    = $DisplayName
  'module'          = $module
  'description'     = $Description
  'owner'           = $Owner
  'holder'          = $Holder
  'year'            = [string](Get-Date).Year
  'date'            = (Get-Date).ToString('yyyy-MM-dd')
  'license_section' = $licenseSection
  'license_npm'     = $licenseNpm
  'license_toml'    = $licenseToml
}

function Expand-Tokens([string]$Text) {
  $t = $Text -replace "`r`n", "`n"
  foreach ($k in $tokens.Keys) { $t = $t.Replace('{{' + $k + '}}', $tokens[$k]) }
  return $t
}

# ---------------------------------------------------------------- build the plan
$plan = New-Object System.Collections.Generic.List[object]
$srcFull = (Resolve-Path -LiteralPath $src).Path
foreach ($f in (Get-ChildItem -LiteralPath $srcFull -Recurse -File -Force | Sort-Object FullName)) {
  $rel = $f.FullName.Substring($srcFull.Length).TrimStart('\', '/')
  if ($rel -ceq 'LICENSE') {
    if (-not $hasLicense) { continue }
    $text = [IO.File]::ReadAllText($licenseSource)
  } else {
    $text = [IO.File]::ReadAllText($f.FullName)
  }
  $plan.Add([pscustomobject]@{ Rel = $rel.Replace('__module__', $module); Text = (Expand-Tokens $text) })
}

$left = @($plan | Where-Object { $_.Text -match '\{\{[a-z_]+\}\}' })
if ($left.Count -gt 0) {
  Fail @(('A starter file has a placeholder this script does not fill: ' + (($left | ForEach-Object { $_.Rel }) -join ', ')))
}

# ---------------------------------------------------------------- report
$mode = if ($Create) { 'CREATE' } else { 'DRY RUN. Nothing is written. Add -Create to write.' }
Write-Host "new-repo: $mode"
Write-Host ("  name        {0}" -f $Name)
Write-Host ("  class       {0}{1}" -f $Class, $(if ($Class -eq 'tool') { ' (' + $Language + ')' } else { '' }))
Write-Host ("  visibility  {0}" -f $Visibility)
Write-Host ("  license     {0}" -f $(if ($hasLicense) { $licenseName } else { 'none, all rights reserved' }))
Write-Host ("  folder      {0}" -f $dest)
Write-Host ("  files       {0}" -f $plan.Count)
foreach ($p in $plan) { Write-Host ('    ' + $p.Rel) }

if (-not $Create) { exit 0 }

# ---------------------------------------------------------------- write
$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($p in $plan) {
  $target = Join-Path $dest $p.Rel
  $dir = Split-Path -Parent $target
  if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $body = $p.Text
  if (-not $body.EndsWith("`n")) { $body += "`n" }
  [IO.File]::WriteAllText($target, $body, $utf8)
}
Write-Host ("new-repo: wrote {0} files to {1}" -f $plan.Count, $dest)

# ---------------------------------------------------------------- next steps
$isNode = $starter -in @('typescript', 'site')
$step = 1
Write-Host 'Next steps:'
Write-Host ("  {0}. cd into the folder." -f $step++)
if (-not $descriptionGiven) {
  $where = if ($starter -eq 'docs') { 'README.md' } else { 'README.md and in the package file' }
  Write-Host ("  {0}. Replace the placeholder description in {1}." -f $step++, $where)
}
if ($isNode) {
  Write-Host ("  {0}. Run npm install, then commit package-lock.json. CI installs from it." -f $step++)
  Write-Host ("  {0}. Run npm run check." -f $step++)
} elseif ($starter -in @('python', 'lab')) {
  Write-Host ("  {0}. Run uv sync, then commit uv.lock. CI installs from it." -f $step++)
  Write-Host ("  {0}. Run just check (install just once with: winget install Casey.Just)." -f $step++)
} else {
  Write-Host ("  {0}. Run just check (install just once with: winget install Casey.Just)." -f $step++)
}
Write-Host ("  {0}. Run git init and make the first commit yourself. This script ran no git." -f $step++)
if ($plan | Where-Object { $_.Text -match '0{40}' }) {
  Write-Host ("  {0}. Replace the placeholder pin (all zeros) in .github\workflows, as the kit CI doc says." -f $step++)
}
Write-Host ("  {0}. Read AGENTS.md and edit it to fit the repo, add the banner images, then delete the banner line in .lycheeignore." -f $step++)
exit 0
