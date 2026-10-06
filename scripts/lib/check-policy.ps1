function Get-CheckPolicy {
  param(
    [string]$Repo,
    [string]$Class,
    [string]$Language,
    [ValidateSet('standard', 'hub-check')][string]$CheckProfile = 'standard',
    [switch]$Strict,
    [switch]$RequirePrPolicy
  )
  if ($CheckProfile -eq 'hub-check') {
    if ($RequirePrPolicy) { throw 'RequirePrPolicy is incompatible with hub-check' }
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
  if ($RequirePrPolicy) { $checks += 'pr-policy' }
  return [pscustomobject]@{
    RequiredChecks = $checks
    WorkflowPath = '.github/workflows/ci.yml'
    RequireChecks = ([bool]$Strict -or $Class -eq 'site')
  }
}

function Get-StatusCheckRequirements {
  param($Ruleset)
  if (-not $Ruleset -or $Ruleset.PSObject.Properties.Name -notcontains 'rules' -or $Ruleset.rules -isnot [array]) {
    throw 'ruleset must contain a rules array'
  }
  foreach ($rule in $Ruleset.rules) {
    if ($rule.type -isnot [string] -or [string]::IsNullOrWhiteSpace($rule.type)) { throw 'ruleset has an invalid rule type' }
  }
  $status = @($Ruleset.rules | Where-Object type -eq required_status_checks)
  if ($status.Count -gt 1) { throw 'ruleset has duplicate required_status_checks rules' }
  if ($status.Count -eq 0) { return }
  $parameters = $status[0].parameters
  if (-not $parameters -or $parameters.PSObject.Properties.Name -notcontains 'required_status_checks' -or $parameters.required_status_checks -isnot [array]) {
    throw 'required_status_checks must contain a requirements array'
  }
  foreach ($name in @('strict_required_status_checks_policy', 'do_not_enforce_on_create')) {
    if ($parameters.PSObject.Properties.Name -contains $name -and $parameters.$name -isnot [bool]) { throw "required check policy has an invalid $name" }
  }
  foreach ($check in $parameters.required_status_checks) {
    if ($check.context -isnot [string] -or [string]::IsNullOrWhiteSpace($check.context)) { throw 'required check has an invalid context' }
    if ($null -ne $check.integration_id -and ($check.integration_id -isnot [int] -and $check.integration_id -isnot [long])) { throw 'required check has an invalid integration_id' }
    if ($null -ne $check.integration_id -and $check.integration_id -lt 0) { throw 'required check integration_id must be nonnegative' }
    $check
  }
}

function Test-StatusCheckRequirement {
  param($Required, [object[]]$Existing)
  foreach ($check in $Existing) {
    if ($check.context -ceq $Required.context -and ($null -eq $Required.integration_id -or $check.integration_id -eq $Required.integration_id)) { return $true }
  }
  return $false
}

function Merge-StatusCheckRules {
  param($Desired, $Existing)
  $currentChecks = @(Get-StatusCheckRequirements $Existing)
  $baselineChecks = @(Get-StatusCheckRequirements $Desired)
  $currentStatus = $Existing.rules | Where-Object type -eq required_status_checks | Select-Object -First 1
  $desiredStatus = $Desired.rules | Where-Object type -eq required_status_checks | Select-Object -First 1
  if ($currentStatus) {
    # Keep full records, including two requirements with the same context but
    # different producers. An unbound baseline never replaces an existing pin.
    $merged = @($currentChecks)
    foreach ($check in $baselineChecks) {
      if (-not (Test-StatusCheckRequirement $check $merged)) { $merged += $check }
    }
    $retained = $currentStatus | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $retained.parameters.required_status_checks = $merged
    if ($desiredStatus) {
      foreach ($name in @('strict_required_status_checks_policy', 'do_not_enforce_on_create')) {
        if ($desiredStatus.parameters.PSObject.Properties.Name -contains $name) {
          $value = $desiredStatus.parameters.$name
          if ($name -eq 'strict_required_status_checks_policy') { $value = [bool]$value -or [bool]$retained.parameters.$name }
          elseif ($retained.parameters.PSObject.Properties.Name -contains $name) { $value = [bool]$value -and [bool]$retained.parameters.$name }
          if ($retained.parameters.PSObject.Properties.Name -contains $name) { $retained.parameters.$name = $value }
          else { $retained.parameters | Add-Member $name $value }
        }
      }
      $Desired.rules = @($Desired.rules | ForEach-Object { if ($_.type -eq 'required_status_checks') { $retained } else { $_ } })
    } else { $Desired.rules += $retained }
  }
  # Additional rule types and existing parameterized protections are retained.
  foreach ($rule in $Existing.rules) {
    if ($rule.type -eq 'required_status_checks') { continue }
    $matching = @($Desired.rules | Where-Object { $_.type -ceq $rule.type })
    if ($matching.Count -eq 0) { $Desired.rules += $rule }
    elseif ($rule.parameters) {
      $Desired.rules = @($Desired.rules | ForEach-Object { if ($_.type -ceq $rule.type) { $rule } else { $_ } })
    }
  }
  return $Desired
}
