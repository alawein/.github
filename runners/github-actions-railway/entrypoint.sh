#!/usr/bin/env bash
# Register once, run one job, exit. Railway ON_FAILURE restart re-registers.
set -euo pipefail

: "${GITHUB_REPO:?Set GITHUB_REPO, e.g. alawein/.github}"
: "${RUNNER_LABELS:=railway,self-hosted,linux,x64,ephemeral}"

REG_TOKEN=""
if [[ -n "${RUNNER_REG_TOKEN:-}" ]]; then
  # Short-lived registration token pasted from GitHub (expires ~1h; one-shot).
  REG_TOKEN="${RUNNER_REG_TOKEN}"
elif [[ -n "${GITHUB_APP_INSTALLATION_TOKEN:-}" ]]; then
  # Preferred: App installation token (or PAT) that can mint registration tokens.
  REG_TOKEN="$(curl -fsSL -X POST \
    -H "Authorization: Bearer ${GITHUB_APP_INSTALLATION_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/repos/${GITHUB_REPO}/actions/runners/registration-token" \
    | jq -r .token)"
  if [[ -z "${REG_TOKEN}" || "${REG_TOKEN}" == "null" ]]; then
    echo "Failed to obtain runner registration token from GitHub API" >&2
    exit 1
  fi
else
  echo "Set GITHUB_APP_INSTALLATION_TOKEN (preferred) or RUNNER_REG_TOKEN" >&2
  exit 1
fi

cd /home/runner || cd "$(dirname "$0")" || true
if [[ ! -x ./config.sh ]]; then
  # Official image places runner files under /home/runner
  cd /home/runner
fi

./config.sh --unattended \
  --url "https://github.com/${GITHUB_REPO}" \
  --token "${REG_TOKEN}" \
  --labels "${RUNNER_LABELS}" \
  --ephemeral \
  --disableupdate \
  --name "railway-${HOSTNAME:-runner}"

./run.sh
