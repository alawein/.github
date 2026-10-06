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

function Get-RulesetRefScope {
  param($Ruleset, [string]$ExpectedTarget)
  if ($Ruleset.target -isnot [string] -or $Ruleset.target -cnotin @('branch', 'tag') -or ($ExpectedTarget -and $Ruleset.target -cne $ExpectedTarget)) {
    throw 'ruleset has an unsupported or incompatible target'
  }
  $conditions = $Ruleset.conditions
  if ($conditions -isnot [pscustomobject] -or $conditions.PSObject.Properties.Name -cnotcontains 'ref_name' -or @($conditions.PSObject.Properties.Name | Where-Object { $_ -cne 'ref_name' }).Count) {
    throw 'ruleset must contain only supported ref_name conditions'
  }
  $scope = $conditions.ref_name
  if ($scope -isnot [pscustomobject] -or @($scope.PSObject.Properties.Name | Where-Object { $_ -cnotin @('include', 'exclude') }).Count) {
    throw 'ruleset has an unsupported ref_name condition'
  }
  foreach ($name in @('include', 'exclude')) {
    if ($scope.PSObject.Properties.Name -cnotcontains $name -or $scope.$name -isnot [array]) { throw "ruleset ref_name $name must be an array" }
  }
  if ($scope.include.Count -eq 0) { throw 'ruleset ref_name include must not be empty' }
  # Exclusions can overlap the baseline or additional refs. Do not guess at
  # fnmatch semantics or silently remove them during a whole-repo setup.
  if ($scope.exclude.Count -ne 0) { throw 'ruleset ref exclusions require an explicit scope reconciliation' }
  $prefix = if ($Ruleset.target -eq 'branch') { 'refs/heads/' } else { 'refs/tags/' }
  foreach ($pattern in $scope.include) {
    if ($pattern -isnot [string] -or $pattern.Length -le $prefix.Length -or -not $pattern.StartsWith($prefix, [StringComparison]::Ordinal) -or $pattern.Trim() -cne $pattern -or $pattern -match '[\r\n]') {
      throw 'ruleset has an unsupported or malformed ref include pattern'
    }
  }
  return $scope
}

function Merge-StatusCheckRules {
  param($Desired, $Existing)
  $desiredScope = Get-RulesetRefScope $Desired
  $currentScope = Get-RulesetRefScope $Existing -ExpectedTarget $Desired.target
  $mergedIncludes = @($currentScope.include)
  foreach ($pattern in $desiredScope.include) {
    if ($mergedIncludes -cnotcontains $pattern) { $mergedIncludes += $pattern }
  }
  $Desired.conditions = $Existing.conditions | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $Desired.conditions.ref_name.include = $mergedIncludes
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
