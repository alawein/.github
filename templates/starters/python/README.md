<!-- Add assets/banner-name-night.png and assets/banner-name-dawn.png (see the brand doc in alawein/.github), then delete the banner line in .lycheeignore. -->
<picture>
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-name-dawn.png">
  <img src="assets/banner-name-night.png" alt="{{display_name}}, on a red ribbon over a pixel-art street at night with lit shop windows" width="760">
</picture>

{{description}}

![Project category: Python](assets/project-label.svg)

<!-- Follow the README writing and labels section in alawein/.github/docs/brand.md. Add only useful labels or verified live badges. -->

## Quick start

```sh
uv sync
uv run {{name}} world
```

`uv sync` also writes `uv.lock`. Commit it: CI installs from it. When it
works, the second command prints `hello, world`.

## Checks

```sh
just check
```

| Task | What it does |
| --- | --- |
| `just lint` | ruff check and ruff format check. Changes nothing |
| `just test` | Runs the tests with pytest. Tests marked `slow` are left out |
| `just build` | Builds the wheel and source archive into `dist/` |
| `just check` | `lint`, then `test`, then `build` |
| `just fix` | Applies the automatic fixes |

Install `just` once with `winget install Casey.Just`.

Every pull request also runs four shared checks: `markdown-lint`,
`link-check`, `actionlint`, and `pr-title`, plus the test check `python-ci`. They are described in
[CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md).

## Contributing

Open an issue first, then a pull request. The rules for branches, commits, and
reviews are in [CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md)
and [delivery rules](https://github.com/alawein/.github/blob/main/docs/system/delivery.md).
Report a vulnerability privately, as described in
[SECURITY](https://github.com/alawein/.github/blob/main/SECURITY.md).

## License

{{license_section}}
