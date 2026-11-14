// Run the real matcher in separate PR and push environments.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const matcher = fileURLToPath(new URL('../check-update-policy.mjs', import.meta.url));
for (const event of ['pull_request', 'push']) {
  const result = spawnSync(process.execPath, [matcher], {
    encoding: 'utf8',
    env: { ...process.env, GITHUB_EVENT_NAME: event },
  });
  assert.equal(result.status, 0, `${event}: ${result.stdout}${result.stderr}`);
  assert.match(result.stdout, /generated PR evidence passed/);
}
console.log('Update-policy matcher passed under independent PR and push contexts.');
