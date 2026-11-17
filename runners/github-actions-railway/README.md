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

4. Service settings: watch path `/runners/github-actions-railway/**` so
   unrelated `main` pushes do not restart the runner; teardown draining
   (about 120 s) so a running job can finish on redeploy; replica limits sized
   to the heaviest job (2 vCPU / 4 GB covers kit jobs). Applying a staged
   setting redeploys the latest `main` commit.
5. Deploy. Confirm the runner appears under repo **Settings → Actions →
   Runners** with the expected labels.
6. Dual-run a **non-required** probe job with
   `runs-on: [self-hosted, railway, ephemeral]`. Keep required checks on
   `ubuntu-24.04` until the probe is green. Remove the probe afterward.
7. Rollback: remove self-hosted labels from YAML → delete the Railway
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
  GitHub-hosted runners. `node-ci.yml` and `python-ci.yml` enforce this: fork
  PRs ignore the `runner` input. Guard any other job with
  `github.event.pull_request.head.repo.fork == false`.
- Set repo **Settings → Actions → General** fork PR approval to "Require
  approval for all external contributors" while this pool is attached.
- The entrypoint unsets `GITHUB_APP_INSTALLATION_TOKEN`, `RUNNER_REG_TOKEN`
  and the minted registration token before `exec ./run.sh`, so job steps do
  not inherit the PAT. Seal the PAT variable in Railway so the dashboard and
  API cannot show it.
- The runner does not deregister itself on shutdown: doing so would keep a
  mint credential alive beside job code. Each redeploy leaves the previous
  runner offline; GitHub removes offline ephemeral runners after one day, or
  remove it under **Settings → Actions → Runners**.
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
| `Dockerfile` | Official `actions-runner` image pin `2.338.2` + jq/git/python |
| `entrypoint.sh` | Mint or accept registration token; `--ephemeral` + `--disableupdate` |
| `railway.toml` | Dockerfile build; restart always after each job |

Image pin tracks the latest stable [`actions/runner`](https://github.com/actions/runner/releases)
tag (`v2.338.2` as of 2026-10-26). Bump the Dockerfile when GitHub deprecates
the pin; keep `--disableupdate` only while the pin is current.
