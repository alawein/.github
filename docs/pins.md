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

No bot bumps these. Change the version and the checksum together. For actionlint, read
the checksum from the release's `actionlint_<version>_checksums.txt` (or the asset digest in
`GET repos/rhysd/actionlint/releases/tags/v<version>`).

| Item | Version | Full SHA or value | Verified | Source repo |
| --- | --- | --- | --- | --- |
| actionlint linux_amd64 archive (in lint-actions.yml) | v1.7.12 | sha256 `8aca8db96f1b94770f1b0d72b6dddcb1ebb8123cb3712530b08cc387b349a3d8` | 2026-09-30 | rhysd/actionlint |
| uv (default of the `uv-version` input in python-ci.yml) | 0.12.21 | version string | 2026-09-30 | astral-sh/uv |

## Pins to this repo

Caller stubs in `templates/workflows/` and the `ci.yml` files in `templates/starters/` pin
`alawein/.github` itself. They pin verified `6f6dbe7f3a23ab830a32007bb52b83fd1bb40563`
(tag `v1.2.0`), verified after required checks passed on 2026-09-30. To bump it, see [ci.md](ci.md), "Bump a pin".

The opt-in `pr-policy.jobs.yml` and `hygiene-weekly.yml` templates separately
pin signed annotated `v1.3.0` at
`b5f8bc3a916b41e22e5e09ec72f34c01428c2933`, verified and published on
2026-10-01. The policy `kit-ref` matches this workflow pin. Hygiene has no
source-ref input; its released workflow checks out reviewed audit source
`ce04a21e332e42c3137b26f3becb0de77086b6cb`. The current source workflow instead
pins `63f7c5cd0a24a99018fc8e0997579449813e6030`; unchanged v1.3.0 callers do
not adopt that audit correction. This adoption leaves all legacy
distributed pins and starter defaults intact. Full workflow/action SHAs bind
source revisions; legacy runtime defaults and hosted OS image contents still
change. See [the v1.3.0 release](https://github.com/alawein/.github/releases/tag/v1.3.0)
and [opt-in installation](ci.md#opt-in-to-pr-policy-and-hygiene).

The release SHA binds the reusable workflow code. Follow-on opt-in templates
and `-RequirePrPolicy` setup/verification support come from reviewed kit main
after adoption merges. Copy those files from main and keep their workflow
pins at the released SHA; this two-phase adoption requires no additional tag.
