#!/usr/bin/env bash
# Register once, run one job, exit. Railway ALWAYS restart re-registers.
set -euo pipefail

: "${GITHUB_REPO:?Set GITHUB_REPO, e.g. alawein/.github}"
: "${RUNNER_LABELS:=railway,self-hosted,linux,x64,ephemeral}"

REG_TOKEN=""
if [[ -n "${GITHUB_APP_INSTALLATION_TOKEN:-}" ]]; then
  # Prefer minting so ALWAYS restarts keep working when a PAT/App token is set.
  # A leftover RUNNER_REG_TOKEN must not win over this path after it expires.
  # Write body to a temp file so HTTP failures keep status on stderr.
  resp="$(mktemp)"
  http_code="$(curl -sS -o "${resp}" -w "%{http_code}" -X POST \
    -H "Authorization: Bearer ${GITHUB_APP_INSTALLATION_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token" \
    || true)"
  if [[ "${http_code}" != "201" && "${http_code}" != "200" ]]; then
    echo "Failed to obtain runner registration token (HTTP ${http_code})" >&2
    rm -f "${resp}"
    exit 1
  fi
  REG_TOKEN="$(jq -r .token < "${resp}")"
  rm -f "${resp}"
  if [[ -z "${REG_TOKEN}" || "${REG_TOKEN}" == "null" ]]; then
    echo "Failed to obtain runner registration token from GitHub API" >&2
    exit 1
  fi
elif [[ -n "${RUNNER_REG_TOKEN:-}" ]]; then
  # Fallback only when no mint credential is set (expires ~1h; one-shot).
  REG_TOKEN="${RUNNER_REG_TOKEN}"
else
  echo "Set GITHUB_APP_INSTALLATION_TOKEN (preferred) or RUNNER_REG_TOKEN" >&2
  exit 1
fi

cd /home/runner

# Railway ALWAYS keeps the filesystem across restarts. actions-runner ephemeral
# mode only removes .runner after a completed job; idle/mid-job restarts leave
# local config and the next config.sh fails with "already configured", which
# becomes an ALWAYS restart loop. Clear prior local state first (best-effort
# remote remove, then delete local files). Never print tokens.
# Keep --disableupdate while the Dockerfile pin matches current stable
# (actions/runner v2.338.2) so deploys stay reproducible.
if [[ -f .runner || -f .credentials || -f .credentials_rsaparams ]]; then
  ./config.sh remove --unattended --token "${REG_TOKEN}" >/dev/null 2>&1 || true
  rm -f .runner .credentials .credentials_rsaparams
fi

./config.sh --unattended \
  --url "https://github.com/${GITHUB_REPO}" \
  --token "${REG_TOKEN}" \
  --labels "${RUNNER_LABELS}" \
  --ephemeral \
  --disableupdate \
  --name "railway-${HOSTNAME:-runner}"

# Do not leave registration credentials in the job listener environment.
# exec replaces this shell so /proc/<pid>/environ no longer holds the originals.
unset REG_TOKEN RUNNER_REG_TOKEN GITHUB_APP_INSTALLATION_TOKEN

exec ./run.sh
