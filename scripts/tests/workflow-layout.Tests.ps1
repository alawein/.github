$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../lib/check-policy.ps1')
$policy = Get-CheckPolicy -Repo 'alawein/example' -Class tool -Language python -Strict -RequirePrPolicy
$primary = @'
jobs:
  markdown-lint:
  link-check:
  actionlint:
  python-ci:
'@
$metadata = @'
on:
  pull_request:
    types: [opened, edited, synchronize, reopened, ready_for_review, converted_to_draft]
concurrency:
  group: policy-${{ github.run_id }}
  cancel-in-progress: false
jobs:
  run-pr-title:
    uses: alawein/.github/.github/workflows/pr-title.yml@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
  run-pr-policy:
    uses: alawein/.github/.github/workflows/pr-policy.yml@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    with:
      kit-ref: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
      require-sections: true
  pr-title:
    needs: [run-pr-title]
    if: ${{ always() }}
  pr-policy:
    needs: [run-pr-policy]
    if: ${{ always() }}
'@
$ready = Get-CheckWorkflowReadiness $policy $primary $metadata
if ($ready.Missing.Count) { throw "split layout rejected: $($ready.Missing -join ', ')" }
$legacy = $primary + "`n  pr-title:`n  pr-policy:`n"
if ((Get-CheckWorkflowReadiness $policy $legacy '').Missing.Count) { throw 'legacy monolithic layout rejected' }
$kit = Get-CheckPolicy -Repo 'alawein/.github' -Class docs -RequirePrPolicy
$localMetadata = $metadata.Replace('alawein/.github/.github/workflows/', '$/.github/workflows/').Replace('@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', '')
if ((Get-CheckWorkflowReadiness $kit $primary $localMetadata).Missing.Count) { throw 'kit same-revision producers rejected' }
if (-not (Get-CheckWorkflowReadiness $policy $primary $localMetadata).Missing.Count) { throw 'foreign caller accepted local implementation sources' }
foreach ($bad in @(
  '',
  $metadata.Replace('edited, ', ''),
  $metadata.Replace('@aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', '@main'),
  $metadata.Replace('kit-ref: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'kit-ref: bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'),
  $metadata.Replace('require-sections: true', 'require-sections: false'),
  $metadata.Replace('      require-sections: true', ''),
  $metadata.Replace('always()', '!cancelled()'),
  $metadata.Replace('github.run_id', 'github.ref')
)) {
  if (-not (Get-CheckWorkflowReadiness $policy $primary $bad).Missing.Count) { throw 'unsafe split layout accepted' }
}
Write-Output 'PASS: split and legacy workflow readiness, immutable sources, events and cancellation'
