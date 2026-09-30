# Pins

Every `uses:` in this repo points to a full 40-character commit SHA, with the tag in a comment.
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

Dependabot cannot bump these. Change the version and the checksum together. For actionlint, read
the checksum from the release's `actionlint_<version>_checksums.txt` (or the asset digest in
`GET repos/rhysd/actionlint/releases/tags/v<version>`).

| Item | Version | Full SHA or value | Verified | Source repo |
| --- | --- | --- | --- | --- |
| actionlint linux_amd64 archive (in lint-actions.yml) | v1.7.12 | sha256 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8` | 2026-09-30 | rhysd/actionlint |
| uv (default of the `uv-version` input in python-ci.yml) | 0.12.21 | version string | 2026-09-30 | astral-sh/uv |

## Pins to this repo

Caller stubs in `templates/workflows/` and the `ci.yml` files in `templates/starters/` pin
`alawein/.github` itself. They carry an all-zero SHA until this repo has a first commit. Replace
it with the real SHA (see [ci.md](ci.md), "After the first commit" and "Bump a pin").
