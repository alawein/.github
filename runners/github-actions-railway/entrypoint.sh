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

./config.sh --unattended \
  --url "https://github.com/${GITHUB_REPO}" \
  --token "${REG_TOKEN}" \
  --labels "${RUNNER_LABELS}" \
  --ephemeral \
  --disableupdate \
  --name "railway-${HOSTNAME:-runner}"

# Do not leave registration credentials in the job listener environment.
unset REG_TOKEN RUNNER_REG_TOKEN GITHUB_APP_INSTALLATION_TOKEN

./run.sh
