<!-- Add assets/banner-name-night.png and assets/banner-name-dawn.png (see the brand doc in alawein/.github), then delete the banner line in .lycheeignore. -->
<img src="assets/banner-name-night.png" alt="{{display_name}}, on a red ribbon over a pixel-art street at night with lit shop windows" width="760">

{{description}}

![Format: Markdown](assets/project-label.svg)

<!-- Follow the README writing and labels section in alawein/.github/docs/brand.md. Add only useful labels or verified live badges. -->

## What it covers

- [Overview](docs/overview.md)

Each page lives in `docs/`. Add a page there and link it from this list.

## Checks

```sh
just check
```

`just check` runs the pinned Markdown lint and checks local links offline.
`just fix` applies the automatic Markdown fixes. Install `just` once with
`winget install Casey.Just`, plus Node.js/npm and lychee.

Every pull request also runs four shared checks: `markdown-lint`,
`link-check`, `actionlint`, and `pr-title`. They are described in
[CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md).
PR links are checked offline; the paired nightly workflow scans external URLs.

## Contributing

Open an issue first, then a pull request. The rules for branches, commits, and
reviews are in [CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md)
and [delivery rules](https://github.com/alawein/.github/blob/main/docs/system/delivery.md).
Report a vulnerability privately, as described in
[SECURITY](https://github.com/alawein/.github/blob/main/SECURITY.md).

## License

{{license_section}}
