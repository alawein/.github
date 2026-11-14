// Exercise the pinned Renovate matcher and template engine without contacting GitHub.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = fileURLToPath(new URL('..', import.meta.url));
const bins = process.env.PATH.split(path.delimiter);
const renovateRoot = bins.map((bin) => path.resolve(bin, '../renovate'))
  .find((candidate) => fs.existsSync(path.join(candidate, 'dist/util/package-rules/index.js')));
assert.ok(renovateRoot, 'Run with npm exec --package=renovate@44.238.1 -- node scripts/check-update-policy.mjs');
const { init } = await import(pathToFileURL(path.join(renovateRoot, 'dist/logger/index.js')));
await init();
const { applyPackageRules } = await import(pathToFileURL(path.join(renovateRoot, 'dist/util/package-rules/index.js')));
const { compile } = await import(pathToFileURL(path.join(renovateRoot, 'dist/util/template/index.js')));
const { mergeChildConfig } = await import(pathToFileURL(path.join(renovateRoot, 'dist/config/utils.js')));
const preset = JSON.parse(fs.readFileSync(process.argv[2] || path.join(root, 'default.json'), 'utf8'));

for (const [updateType, manager, depName, wanted] of [
  ['patch', 'npm', 'example-library', true],
  ['patch', 'pep621', 'example-library', true],
  ['minor', 'npm', 'example-library', false],
  ['major', 'npm', 'example-library', false],
  ['pin', 'npm', 'example-library', false],
  ['digest', 'github-actions', 'actions/checkout', false],
  [undefined, 'npm', 'example-library', false],
  ['patch', 'github-actions', 'actions/checkout', false],
  ['patch', 'dockerfile', 'example-image', false],
  ['patch', 'npm', 'esbuild', false],
  ['patch', 'pep621', 'cryptography', false],
]) {
  const result = await applyPackageRules({ ...preset, updateType, manager, depName, packageName: depName });
  assert.equal(result.automerge, wanted, `${manager}/${depName}/${updateType} merge eligibility`);
  assert.equal(result.ignoreTests, false, 'Update automation must respect test results');
}

const consumerFile = path.join(root, 'renovate.json');
if (fs.existsSync(consumerFile)) {
  const consumer = JSON.parse(fs.readFileSync(consumerFile, 'utf8'));
  for (const manager of ['npm', 'pep621']) {
    const config = mergeChildConfig(preset, consumer);
    const result = await applyPackageRules({ ...config, updateType: 'patch', manager,
      depName: 'example-library', packageName: 'example-library' });
    assert.equal(result.automerge, false, 'Unverified required independent review must hold consumer auto-merge');
  }
}

const branch = compile(preset.branchPrefix + preset.branchTopic, {
  depNameSanitized: 'Scope.Nested/Package', newMajor: 3,
});
assert.equal(branch, 'chore/deps-scope-nested-package-3');
const unversionedBranch = compile(preset.branchPrefix + preset.branchTopic, {
  depNameSanitized: 'Scope.Nested/Package',
});
assert.equal(unversionedBranch, 'chore/deps-scope-nested-package', 'Non-semver updates need a valid branch too');
const body = compile(preset.prBodyTemplate, {
  table: '| Package | Change |\n| --- | --- |\n| Example | 1.0.0 to 1.0.1 |',
}, false); // Match Renovate's PR-body renderer; these are body-section variables.
const scratch = fs.mkdtempSync(path.join(os.tmpdir(), 'update-policy-'));
try {
  const event = path.join(scratch, 'event.json');
  for (const ref of [branch, unversionedBranch]) {
    const fixture = {
      _event_name: 'pull_request', action: 'opened', number: 1,
      pull_request: { number: 1, draft: false, body, head: { ref },
        user: { login: 'renovate[bot]', type: 'Bot' } },
    };
    fs.writeFileSync(event, JSON.stringify(fixture));
    // The synthetic fixture is a PR even when the surrounding run is a push.
    const env = { ...process.env, GITHUB_EVENT_NAME: 'pull_request' };
    const args = [
      path.join(root, 'scripts/check-pr-policy.py'), '--event', event, '--require-sections',
    ];
    const result = spawnSync(process.env.PYTHON || 'python', args, { encoding: 'utf8', env });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    fs.writeFileSync(event, JSON.stringify({
      ...fixture, pull_request: { ...fixture.pull_request, body: '' },
    }));
    const rejected = spawnSync(process.env.PYTHON || 'python', args, { encoding: 'utf8', env });
    assert.equal(rejected.status, 1, rejected.stdout + rejected.stderr);
    assert.match(rejected.stdout, /Ready PR needs an issue reference/);
  }
} finally {
  const resolved = fs.realpathSync(scratch);
  assert.equal(path.dirname(resolved), fs.realpathSync(os.tmpdir()));
  assert.ok(path.basename(resolved).startsWith('update-policy-'));
  fs.rmSync(scratch, { recursive: true, force: true });
}
console.log('Update-rule cases, consumer review hold, and generated PR evidence passed. No network or merge performed.');
