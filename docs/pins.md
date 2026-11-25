# Pins

External actions and reusable workflow calls pin full 40-character commit SHAs,
with the tag in a comment. Same-repository `./` workflow calls use the current revision.
Each row was checked on the date shown with the read-only GitHub API call
`GET repos/<owner>/<repo>/commits/<tag>`, which returns the tag's commit SHA.
For rows dated 2026-09-30, `releases/latest` also confirmed the tag was the newest
stable release at that time. For rows dated 2026-11-13, `releases/latest` was not
checked, so their newest-release status is unknown. The table lists exactly the action
pins used in `.github/workflows/`. When a workflow changes, regenerate it from those files.

| Action | Tag | Full SHA | Verified | Source repo |
| --- | --- | --- | --- | --- |
| actions/checkout | v7.0.1 | `3d3c42e5aac5ba805825da76410c181273ba90b1` | 2026-09-30 | actions/checkout |
| actions/setup-node | v7.0.0 | `820762786026740c76f36085b0efc47a31fe5020` | 2026-09-30 | actions/setup-node |
| actions/setup-node | v7.1.0 | `949feb2413d6458794dcd2491c4babbbce0c15c1` | 2026-11-13 | actions/setup-node |
| actions/setup-python | v7.1.0 | `6d4fd22b20465ccc0f7354476588e8df7c9ca0e0` | 2026-11-13 | actions/setup-python |
| amannn/action-semantic-pull-request | v6.1.2 | `2252a14e810aa9b85c2d560bd7070c802206ecf6` | 2026-11-13 | amannn/action-semantic-pull-request |
| anthropics/claude-code-action | v1.0.283 | `f431adaf77e0fecf918431e75a2b5b45b85af002` | 2026-11-20 | anthropics/claude-code-action |
| astral-sh/setup-uv | v10.3.3 | `68559e99cc807c1eb7e9238fd43a15bba460eec2` | 2026-11-13 | astral-sh/setup-uv |
| DavidAnson/markdownlint-cli2-action | v25.0.0 | `696eb3f2509270d7b882d2aa68347bc676e7af34` | 2026-11-13 | DavidAnson/markdownlint-cli2-action |
| lycheeverse/lychee-action | v2.9.0 | `e7477775783ea5526144ba13e8db5eec57747ce8` | 2026-09-30 | lycheeverse/lychee-action |

## Pins that are not `uses:` lines

Renovate may propose changes to recognized package and action manifests. Update
standalone binary versions and checksums together through reviewed changes.
For actionlint, read
the checksum from the release's `actionlint_<version>_checksums.txt` (or the asset digest in
`GET repos/rhysd/actionlint/releases/tags/v<version>`).

| Item | Version | Full SHA or value | Verified | Source repo |
| --- | --- | --- | --- | --- |
| actionlint linux_amd64 archive (in lint-actions.yml and ci.yml metadata-tests) | v1.7.12 | sha256 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8` | 2026-09-30 | rhysd/actionlint |
| just x86_64 linux musl archive (in ci.yml metadata-tests) | 1.59.0 | sha256 `409044617b6f06517c1035e55ca38c8c856ff8b650e41bc2aa1ef82d5903a23e` (release asset digest) | 2026-11-11 | casey/just |
| lychee x86_64 linux musl archive (in ci.yml metadata-tests; matches lychee-action v2.9.0's default) | 0.24.2 | sha256 `73657a111819a30c47c08352896796f23d64e4eb2b3ed39b6d32149241566fc5` (release asset digest, tag `lychee-v0.24.2`) | 2026-11-11 | lycheeverse/lychee |
| zizmor x86_64 linux gnu archive (in lint-zizmor.yml) | v1.32.0 | sha256 `bb110cc765eca9cd7efb2e284a956be5974c60027b0970f16397d86208a9957b` (release asset digest) | 2026-11-11 | zizmorcore/zizmor |
| PyYAML wheels (tests/requirements.txt) | 6.0.3 | sha256 per wheel, in the file | 2026-11-11 | yaml/pyyaml |
| uv (default of the `uv-version` input in python-ci.yml) | 0.12.21 | version string | 2026-09-30 | astral-sh/uv |
| Renovate validator and offline rule tests (ci.yml metadata-tests) | 44.238.1 | exact npm version | 2026-11-13 | renovatebot/renovate |
| Node for the Renovate validator (ci.yml metadata-tests) | 26.13.0 | exact runtime version | 2026-11-13 | nodejs/node |

## Pins to this repo

Distributed callers and starters freeze to reviewed `main` commit
`cc3b595f8e9e92a9ed6fc63b3be177cc8a571965` (observed 2026-11-17 via
`gh api repos/alawein/.github/commits/main --jq .sha`). Their `kit-ref` values match
the reusable workflow SHA. Trailing comments remain `# quality gates` until a release
tag is cut; then switch comments to `# vX.Y.Z`. Code starters opt into mandatory lint;
the policy fragment opts into complete review evidence. `tests/test_workflow_gates.py`
and `tests/test_publication_contract.py` check that ready-to-copy templates pin one
revision, so caller pins and `kit-ref` values change together.

`templates/workflows/claude-review.yml` is **withheld** from ready-to-copy
distribution (`claude-review.WITHHELD.md`): the freeze SHA has no
`.github/workflows/claude-review.yml` (that path landed later on `main`). Do not
invent a pin, pin `@main`, or self-pin. Restore a consumer template only when a
reviewed freeze or release tag contains the reusable workflow. Claude review stays
inactive until the owner names activation.

Existing published callers on older pins (including signed `v1.4.0` at
`f5dbd4d7656e286e20d2aa24463253c32a56521b`) retain their old behavior until they
adopt this freeze. The hygiene workflow checks out reviewed audit source
`98c7496007ae504a3509be1c29d02afa87640aca` and runs it with `--token-limited`.
For published pins, use the full SHA with a `# vX.Y.Z` comment so dependency updates
can propose the next bump. To bump, see [ci.md](ci.md), "Bump a pin".
