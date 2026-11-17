# Ephemeral GitHub Actions runner for Railway dual-run experiments.
# Pin matches Phase 5 of the workflow-audit plan; bump deliberately.
FROM ghcr.io/actions/actions-runner:2.329.0

USER root
# Base image already ships curl/git/python; --no-upgrade avoids flaky
# git-core PPA upgrades (503 during Railway build).
RUN apt-get update \
 && apt-get install -y --no-install-recommends --no-upgrade \
    curl ca-certificates git jq python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER runner
ENTRYPOINT ["/entrypoint.sh"]
