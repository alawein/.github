# Ephemeral GitHub Actions runner for Railway dual-run experiments.
# Pin matches Phase 5 of the workflow-audit plan; bump deliberately.
FROM ghcr.io/actions/actions-runner:2.329.0

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git jq python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER runner
ENTRYPOINT ["/entrypoint.sh"]
