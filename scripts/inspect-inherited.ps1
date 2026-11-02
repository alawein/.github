<#
.SYNOPSIS
  Read-only inspection of a repository someone else started.

.DESCRIPTION
  Prints provenance, license, remotes, history, dependency files, script names,
  secret-file names, and deployment files. It does not install, test, commit,
  push, or print secret contents. Exit 2 means do not execute old install or
  lifecycle scripts. Repair, relaunch, and publication stay false.

.PARAMETER Path
  Repository root. It must already be a git repository with at least one commit.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Say([string]$Key, [string]$Value) {
  Write-Host ("{0}: {1}" -f $Key, $Value)
}

if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
  Say 'inspect-inherited' 'path missing'
  exit 1
}

$root = (Resolve-Path -LiteralPath $Path).Path
if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
  Say 'inspect-inherited' 'not a git repository'
  exit 1
}

Push-Location -LiteralPath $root
try {
  $sha = (git rev-parse HEAD 2>$null)
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) {
    Say 'inspect-inherited' 'no commits'
    exit 1
  }
  $sha = $sha.Trim()

  $remoteLines = @(git remote 2>$null | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $remoteText = if ($remoteLines.Count -eq 0) { 'none' } else { ($remoteLines -join ',') }

  $license = 'missing'
  foreach ($name in @('LICENSE', 'LICENSE.md')) {
    if (Test-Path -LiteralPath (Join-Path $root $name)) { $license = $name; break }
  }

  $count = (git rev-list --count HEAD).Trim()

  $depNames = @('package.json', 'package-lock.json', 'pyproject.toml', 'uv.lock', 'requirements.txt')
  $deps = @($depNames | Where-Object { Test-Path -LiteralPath (Join-Path $root $_) })
  $depText = if ($deps.Count -eq 0) { 'none' } else { ($deps -join ',') }

  $scriptNames = New-Object System.Collections.Generic.List[string]
  $lifecycleNames = @('preinstall', 'install', 'postinstall', 'prepare', 'prepublish', 'prepublishOnly',
    'publish', 'version', 'dependencies')
  $lifecycleEvents = @('install', 'prepare', 'pack', 'publish', 'test', 'start', 'stop', 'restart', 'version')
  $packagePath = Join-Path $root 'package.json'
  if (Test-Path -LiteralPath $packagePath) {
    $package = Get-Content -Raw -LiteralPath $packagePath | ConvertFrom-Json
    if ($package.PSObject.Properties.Name -contains 'scripts' -and $null -ne $package.scripts) {
      foreach ($prop in $package.scripts.PSObject.Properties) { $scriptNames.Add($prop.Name) }
    }
  }
  $scriptText = if ($scriptNames.Count -eq 0) { 'none' } else { ($scriptNames -join ',') }
  # Built-in events can have hooks without an explicit event script. Other
  # pre/post names are hooks only when their matching package script exists.
  $lifecycle = @($scriptNames | Where-Object {
    ($lifecycleNames -contains $_) -or
      (($_ -cmatch '^(pre|post)(.+)$') -and
        (($lifecycleEvents -ccontains $Matches[2]) -or ($scriptNames -ccontains $Matches[2])))
  })
  $lifecycleText = if ($lifecycle.Count -eq 0) { 'none' } else { ($lifecycle -join ',') }

  $secretMatchers = @(
    '(?i)^\.(env|npmrc|pypirc|pem|key)$',
    '(?i)^\.(env|npmrc|pypirc)\.',
    '(?i)(^|/)(credentials|id_rsa|id_ed25519)(\.|$)',
    '(?i)\.(pem|key|p12|pfx)$'
  )
  $secrets = New-Object System.Collections.Generic.List[string]
  $deployMatchers = @('vercel.json', 'netlify.toml', 'fly.toml', 'wrangler.toml', 'Dockerfile')
  $deploys = New-Object System.Collections.Generic.List[string]
  Get-ChildItem -LiteralPath $root -Recurse -Force -File | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    if ($rel -eq '.git' -or $rel.StartsWith('.git/')) { return }
    foreach ($pattern in $secretMatchers) {
      if ($rel -match $pattern -or ($_.Name -match $pattern)) { $secrets.Add($rel); break }
    }
    if ($deployMatchers -contains $_.Name) { $deploys.Add($rel) }
  }
  $secretText = if ($secrets.Count -eq 0) { 'none' } else { ($secrets -join ',') }
  $deployText = if ($deploys.Count -eq 0) { 'none' } else { ($deploys -join ',') }

  $dirty = @(git status --porcelain | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $dirtyText = if ($dirty.Count -eq 0) { 'none' } else { (($dirty | ForEach-Object { $_.Trim() }) -join ',') }

  $execute = if ($lifecycleText -ne 'none' -or $secretText -ne 'none') { 'refused' } else { 'allowed' }

  Say 'inspect-inherited' 'report'
  Say 'starting_revision' $sha
  Say 'remotes' $remoteText
  Say 'license' $license
  Say 'commits' $count
  Say 'dependency_files' $depText
  Say 'scripts' $scriptText
  Say 'lifecycle_scripts' $lifecycleText
  Say 'secret_paths' $secretText
  Say 'deploy_files' $deployText
  Say 'dirty_paths' $dirtyText
  Say 'repair_verified' 'false'
  Say 'relaunch_ready' 'false'
  Say 'published' 'false'
  Say 'execute' $execute

  if ($execute -eq 'refused') { exit 2 }
  exit 0
}
finally {
  Pop-Location
}
