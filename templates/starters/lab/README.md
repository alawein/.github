<!-- Add assets/banner-name-night.png and assets/banner-name-dawn.png (see the brand doc in alawein/.github), then delete the banner line in .lycheeignore. -->
<picture>
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-name-dawn.png">
  <img src="assets/banner-name-night.png" alt="{{display_name}}, on a red ribbon over a pixel-art street at night with lit shop windows" width="760">
</picture>

{{description}}

![Project category: Research code](assets/project-label.svg)

<!-- Follow the README writing and labels section in alawein/.github/docs/brand.md. Add only useful labels or verified live badges. -->

## Question

The one question this lab tries to answer, in a sentence. If you cannot write
it, the lab is not ready.

## Status

Active. One of: active, paused, done. A lab with no commit for 90 days is
promoted to its own tool repo or archived.

## Reproduce

```sh
uv sync
just check
```

`uv sync` also writes `uv.lock`. Commit it: CI installs from it. When it works,
`just check` ends with no errors. Then list here, in order, the commands that
rebuild each result in `results/`. Data sources are in
[data/README.md](data/README.md). Install `just` once with
`winget install Casey.Just`.

## Checks

| Task | What it does |
| --- | --- |
| `just lint` | ruff check and ruff format check. Changes nothing |
| `just test` | Runs the tests with pytest. Tests marked `slow` are left out |
| `just build` | Nothing to build in a lab |
| `just check` | `lint`, then `test`, then `build` |
| `just fix` | Applies the automatic fixes |

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
