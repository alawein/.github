<!--
README template for a new alawein repo. Copy it to README.md, replace every
{{token}}, and delete this comment.

Why there is no H1: the banner carries the repo name as large type, so a
heading would repeat it. The alt text of the banner carries the name for
screen readers and search. Start the first section at H2.

Banner: make banner-name-night.png and banner-name-dawn.png with the brand generator
(see docs/brand.md) and put them in assets/. The dawn image shows in light
mode and the night image everywhere else.

Keep it short. No hosted widgets, no badge walls, no stats cards.
-->
<picture>
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-name-dawn.png">
  <img src="assets/banner-name-night.png" alt="{{Repo display name}}, on a red ribbon over a pixel-art street at night with lit shop windows" width="760">
</picture>

{{One paragraph. What this does and why it exists, in two or three plain sentences. Start with what it does. Say who it is for. No adjectives that sell.}}

## Quick start

```sh
{{install command}}
{{run command}}
```

{{One line on what the reader should see when it works.}}

## Checks

```sh
{{test command}}
{{lint command}}
```

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

{{License name}}. See [LICENSE](LICENSE).
