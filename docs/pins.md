# Pins

External actions and reusable workflow calls pin full 40-character commit SHAs,
with the tag in a comment. Same-repository `./` workflow calls use the current revision.
Each row was checked on the date shown with read-only GitHub API calls:
`GET repos/<owner>/<repo>/commits/<tag>` returns the SHA, and `releases/latest` confirmed the tag
is the newest stable one. The table lists exactly the actions used in `.github/workflows/`. When a
workflow changes, regenerate it from those files.

| Action | Tag | Full SHA | Verified | Source repo |
| --- | --- | --- | --- | --- |
| actions/checkout | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` | 2026-09-30 | actions/checkout |
| actions/setup-node | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` | 2026-09-30 | actions/setup-node |
| actions/setup-python | v7.0.0 | `5fda3b95a4ea91299a34e894583c3862153e4b97` | 2026-09-30 | actions/setup-python |
| amannn/action-semantic-pull-request | v6.1.1 | `48f256284bd46cdaab1048c3721360e808335d50` | 2026-09-30 | amannn/action-semantic-pull-request |
| astral-sh/setup-uv | v10.2.0 | `c18668ad3cf93ea998bef934396af7bb5c839dc7` | 2026-09-30 | astral-sh/setup-uv |
| DavidAnson/markdownlint-cli2-action | v24.2.0 | `21c1be1b93ad9ed58fa840aacc3f279cde2a72ff` | 2026-09-30 | DavidAnson/markdownlint-cli2-action |
| lycheeverse/lychee-action | v2.9.0 | `e7477775783ea5526144ba13e8db5eec57747ce8` | 2026-09-30 | lycheeverse/lychee-action |

## Pins that are not `uses:` lines

No bot bumps these, except the PyYAML wheels, which Dependabot pip updates with their hashes.
Otherwise change the version and the checksum together. For actionlint, read
the checksum from the release's `actionlint_<version>_checksums.txt` (or the asset digest in
`GET repos/rhysd/actionlint/releases/tags/v<version>`).

| Item | Version | Full SHA or value | Verified | Source repo |
| --- | --- | --- | --- | --- |
| actionlint linux_amd64 archive (in lint-actions.yml and ci.yml metadata-tests) | v1.7.12 | sha256 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8` | 2026-09-30 | rhysd/actionlint |
| just x86_64 linux musl archive (in ci.yml metadata-tests) | 1.59.0 | sha256 `409044617b6f06517c1035e55ca38c8c856ff8b650e41bc2aa1ef82d5903a23e` (release asset digest) | 2026-11-11 | casey/just |
| lychee x86_64 linux musl archive (in ci.yml metadata-tests; matches lychee-action v2.9.0's default) | 0.24.2 | sha256 `73657a111819a30c47c08352896796f23d64e4eb2b3ed39b6d32149241566fc5` (release asset digest, tag `lychee-v0.24.2`) | 2026-11-11 | lycheeverse/lychee |
| zizmor x86_64 linux gnu archive (in lint-zizmor.yml) | v1.32.0 | sha256 `bb110cc765eca9cd7efb2e284a956be5974c60027b0970f16397d86208a9957b` (release asset digest) | 2026-11-11 | zizmorcore/zizmor |
| PyYAML wheels (tests/requirements.txt; Dependabot pip) | 6.0.3 | sha256 per wheel, in the file | 2026-11-11 | yaml/pyyaml |
| uv (default of the `uv-version` input in python-ci.yml) | 0.12.21 | version string | 2026-09-30 | astral-sh/uv |

## Pins to this repo

Every caller stub in `templates/workflows/`, every starter `ci.yml` in `templates/starters/`,
and the opt-in `pr-policy.jobs.yml` (including its `kit-ref`) and `hygiene-weekly.yml` pin
`alawein/.github` at signed annotated `v1.4.0`,
`f5dbd4d7656e286e20d2aa24463253c32a56521b`, tagged on 2026-11-11 after CI passed on that
commit. `tests/test_workflow_gates.py` fails if templates pin more than one revision, so a
release bumps them all together. Its hygiene workflow checks out reviewed audit source
`98c7496007ae504a3509be1c29d02afa87640aca` and runs it with `--token-limited`. Consumers pin
the full SHA with a `# vX.Y.Z` comment so Dependabot github-actions can propose the next bump.
To bump, see [ci.md](ci.md), "Bump a pin".
