# Ephemeral GitHub Actions runner (Railway)

Docker image and Railway config for a **one-job ephemeral** self-hosted runner
aimed at dual-running heavy kit jobs (for example `metadata-tests`) off
GitHub-hosted minutes. Labels: `railway,self-hosted,linux,x64,ephemeral`.

## Deploy (Railway)

1. Create a dedicated Railway project (do not reuse unrelated apps).
2. Create a service from this directory (root
   `runners/github-actions-railway` if deploying from `alawein/.github`).
3. Set variables (names only in git; values only in Railway):

   | Variable | Purpose |
   | --- | --- |
   | `GITHUB_REPO` | Target repo, e.g. `alawein/.github` |
   | `RUNNER_LABELS` | `railway,self-hosted,linux,x64,ephemeral` |
   | `GITHUB_APP_INSTALLATION_TOKEN` | **Preferred.** Fine-scoped PAT (or App token mint path) that can create runner registration tokens. Entrypoint mints a fresh registration token on every start when this is set. A fixed GitHub App installation token expires in about one hour and fails later restarts unless refreshed; prefer a PAT whose expiry covers the service lifetime. |
   | `RUNNER_REG_TOKEN` | **Fallback only** when `GITHUB_APP_INSTALLATION_TOKEN` is unset. Short-lived registration token from GitHub (expires ~1h; one-shot). Do not leave an expired value set alongside a PAT — the entrypoint ignores `RUNNER_REG_TOKEN` whenever the App/PAT var is present. |

4. Deploy. Confirm the runner appears under repo **Settings → Actions →
   Runners** with the expected labels.
5. Dual-run a **non-required** probe job with
   `runs-on: [self-hosted, railway, ephemeral]`. Keep required checks on
   `ubuntu-24.04` until the probe is green. Remove the probe afterward.
6. Rollback: remove self-hosted labels from YAML → delete the Railway
   service → revoke the App/PAT.

### Mint a registration token (human)

If automation cannot mint tokens (missing admin / manage_runners):

1. Open `https://github.com/alawein/.github/settings/actions/runners/new`.
2. Copy the short-lived registration token from the configure step (do not
   commit or paste it into chat).
3. Prefer setting `GITHUB_APP_INSTALLATION_TOKEN` to a fine-scoped PAT that
   can call `POST /repos/{owner}/{repo}/actions/runners/registration-token`
   and whose expiry covers the service lifetime (`restartPolicyType =
   ALWAYS` restarts then mint fresh registration tokens). Use
   `RUNNER_REG_TOKEN` only when that PAT/App path is unavailable (single
   boot); clear it once a mint credential is configured.
4. Redeploy / restart the service once.

Never commit tokens, print them in logs, or store them in this repo.

## Job opt-in (after green dual-run)

```yaml
jobs:
  metadata-tests:
    runs-on: [self-hosted, railway, ephemeral]
    # Keep ubuntu-24.04 until the runner pool is proven green in parallel.
```

Prefer an input flag on reusables rather than hard-switching required jobs.

## Security

- Always start with `--ephemeral` (this image does).
- On every start the entrypoint clears leftover `.runner` / `.credentials*`
  (and best-effort `config.sh remove`) before re-registering, so Railway
  `ALWAYS` restarts after idle or mid-job stops do not loop on "already
  configured".
- Do **not** attach `railway` labels to fork `pull_request` jobs; keep forks on
  GitHub-hosted runners. Guard with
  `github.event.pull_request.head.repo.fork == false` when needed.
- Do not place privileged secrets on the self-hosted pool beyond registration.
- Prefer `permissions: contents: read` on jobs that land here.
- Never use this pool for `pull_request_target` that can reach secrets.
- Egress: allowlist GitHub, npm, and PyPI as needed; tighten Railway network
  policy when available (exact ACL UX UNVERIFIED until confirmed in dashboard).

## Cost notes (modelled)

- GitHub-hosted Linux bills per job-minute (ceil). Many short kit jobs inflate
  billable minutes vs wall clock.
- Railway bills compute time for the runner service. Moving long jobs can cut
  hosted minutes substantially; treat 80–90% savings as a **model** until one
  billing cycle compares invoices.
- Idle restart loops still consume Railway resources — watch crash/restart
  metrics if registration fails.

## Files

| File | Role |
| --- | --- |
| `Dockerfile` | Official `actions-runner` image + jq/git/python |
| `entrypoint.sh` | Mint or accept registration token; `--ephemeral` run |
| `railway.toml` | Dockerfile build; restart always after each job |
