<!-- Add assets/banner-name-night.png and assets/banner-name-dawn.png (see the brand doc in alawein/.github), then delete the banner line in .lycheeignore. -->
<picture>
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-name-dawn.png">
  <img src="assets/banner-name-night.png" alt="{{display_name}}, on a red ribbon over a pixel-art street at night with lit shop windows" width="760">
</picture>

{{description}}

## What it covers

- [Overview](docs/overview.md)

Each page lives in `docs/`. Add a page there and link it from this list.

## Checks

```sh
just check
```

`just check` runs the markdown lint and the link check. `just fix` applies the
automatic fixes. Install `just` once with `winget install Casey.Just`.

Every pull request also runs four shared checks: `markdown-lint`,
`link-check`, `actionlint`, and `pr-title`. They are described in
[CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md).

## Contributing

Open an issue first, then a pull request. The rules for branches, commits, and
reviews are in [CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md)
and [delivery rules](https://github.com/alawein/.github/blob/main/docs/system/delivery.md).
Report a vulnerability privately, as described in
[SECURITY](https://github.com/alawein/.github/blob/main/SECURITY.md).

## License

{{license_section}}
