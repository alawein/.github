function Get-CheckPolicy {
  param(
    [string]$Repo,
    [string]$Class,
    [string]$Language,
    [ValidateSet('standard', 'hub-check')][string]$CheckProfile = 'standard',
    [switch]$Strict
  )
  if ($CheckProfile -eq 'hub-check') {
    if ($Repo -cne 'alawein/career-engine' -or $Class -cne 'tool' -or $Language -cne 'typescript') {
      throw 'hub-check requires the approved hub TypeScript tool'
    }
    return [pscustomobject]@{
      RequiredChecks = @('check')
      WorkflowPath = '.github/workflows/check.yml'
      RequireChecks = $true
    }
  }
  $checks = @('markdown-lint', 'link-check', 'actionlint', 'pr-title')
  if ($Class -eq 'site') { $checks += 'node-ci' }
  elseif ($Class -eq 'lab') { $checks += 'python-ci' }
  elseif ($Class -eq 'tool') {
    $checks += $(if ($Language -eq 'python') { 'python-ci' } else { 'node-ci' })
  }
  return [pscustomobject]@{
    RequiredChecks = $checks
    WorkflowPath = '.github/workflows/ci.yml'
    RequireChecks = ([bool]$Strict -or $Class -eq 'site')
  }
}
