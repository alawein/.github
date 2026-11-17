# Ephemeral GitHub Actions runner for Railway dual-run experiments.
# Pin to current stable actions/runner release; bump deliberately.
# Source: https://github.com/actions/runner/releases/tag/v2.338.2
FROM ghcr.io/actions/actions-runner:2.338.2

USER root
# Base image already ships curl/git/python; --no-upgrade avoids flaky
# git-core PPA upgrades (503 during Railway build).
RUN apt-get update \
 && apt-get install -y --no-install-recommends --no-upgrade \
    curl ca-certificates git jq python3 python3-venv \
 && rm -rf /var/lib/apt/lists/*

# PowerShell for the generator tests, which hosted ubuntu-24.04 runners ship.
# Pinned LTS release and the sha256 GitHub publishes for the asset; bump both together.
ARG PWSH_VERSION=7.6.10
ARG PWSH_SHA256=e261cabc91c78a9afe8d1e5f24731ab0d38204735ab2ec94b0af55102652e10d
RUN curl -fsSLo /tmp/pwsh.tar.gz \
    "https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-x64.tar.gz" \
 && echo "${PWSH_SHA256}  /tmp/pwsh.tar.gz" | sha256sum -c - \
 && mkdir -p /opt/microsoft/powershell/7 \
 && tar -xzf /tmp/pwsh.tar.gz -C /opt/microsoft/powershell/7 \
 && chmod +x /opt/microsoft/powershell/7/pwsh \
 && ln -s /opt/microsoft/powershell/7/pwsh /usr/local/bin/pwsh \
 && rm /tmp/pwsh.tar.gz \
 && pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER runner
ENTRYPOINT ["/entrypoint.sh"]
