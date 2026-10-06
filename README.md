<picture>
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-dawn.png">
  <img src="assets/banner-night.png" alt="Pixel-art market street with lit shop windows and paper lanterns" width="760">
</picture>

# .github

Shared GitHub standards for [alawein](https://github.com/alawein): community
files, reusable workflows, rulesets, scripts, and repo starters. This README is
the entry point for using and maintaining the kit. Shared community files
become defaults for repositories that do not carry their own copy.

## Quick start

Install PowerShell, GitHub CLI, and [just](https://github.com/casey/just).
Choose a [repo class](docs/system/repos.md), then preview a new local folder:

```powershell
.\scripts\new-repo.ps1 -Name label-sync -Class tool -Language python -Description "Sync labels from a file." -Path C:\src
```

`new-repo.ps1` plans first; `-Create` writes the new folder. The printed next
steps cover its dependencies and first commit. To preview the standard for an
existing repo, run `scripts/setup-repo.ps1` without `-Apply`; see
[CI setup](docs/ci.md) before applying it.

## Checks

From this repo's root, run `just check` for Markdown lint, offline local links,
and the docs build step. `just lint`, `just test`, `just build`, and `just fix`
run the individual tasks. The Markdown runner is pinned to
`markdownlint-cli2@0.23.2`; install lychee for the link check. CI also runs
`actionlint` and `pr-title` as described in [CI](docs/ci.md).

## Where files belong

| Path | Purpose |
| --- | --- |
| [Repo shape](docs/system/repos.md), [delivery](docs/system/delivery.md), and [projects](docs/system/projects.md) | Repository layout, change delivery, and work tracking |
| [Agents](docs/system/agents.md), [reviewers](docs/system/reviewers.md), and [task examples](docs/system/agents-examples.md) | Agent instructions, review routing, and task briefs |
| [CI](docs/ci.md) and [pins](docs/pins.md) | Checks, reusable workflows, and verified pins |
| [Brand](docs/brand.md) and [archive](docs/archive.md) | Repo images and retirement rules |
| [Vercel](docs/vercel.md) | Site deployment and domain guidance |
| [Starters](templates/starters) | Minimal docs, TypeScript, Python, site, and lab repos |
| [Templates](templates) | Workflows, ownership, README, and review files |
| [Issue forms](.github/ISSUE_TEMPLATE) | Shared bug, feature, and task forms with chooser settings |
| [Scripts](scripts) and [rulesets](rulesets) | Local setup and GitHub policy definitions |
| [.github/workflows](.github/workflows) | Reusable checks and this kit's own CI |
| [assets](assets) | Approved repository artwork |
| [docs](docs) | One focused reference per topic, linked here |
| [Contributing](CONTRIBUTING.md) and [security](SECURITY.md) | Change process and private vulnerability reporting |

Keep useful source in the matching folder. ZIP bundles, generated logs,
temporary exports, and duplicate instruction pages do not belong in the kit.

## Contributing

Follow the [delivery rules](docs/system/delivery.md), run `just check`, and
record check results in the pull request. Report security issues through
[SECURITY.md](SECURITY.md).

## License

MIT. See [LICENSE](LICENSE).
