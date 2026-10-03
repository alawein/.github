<!-- Add assets/banner-name-night.png and assets/banner-name-dawn.png (see the brand doc in alawein/.github), then delete the banner line in .lycheeignore. -->
<picture>
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-name-dawn.png">
  <img src="assets/banner-name-night.png" alt="{{display_name}}, on a red ribbon over a pixel-art street at night with lit shop windows" width="760">
</picture>

{{description}}

## Quick start

```sh
npm install
npm run dev
```

`npm install` also writes `package-lock.json`. Commit it: CI installs from it.
When it works, the dev server prints a local address and the page shows the
site name.

## Checks

| Task | What it does |
| --- | --- |
| `npm run lint` | ESLint, Prettier, and `astro check`. Changes nothing |
| `npm test` | Runs the tests with Vitest |
| `npm run build` | Builds the site into `dist/` |
| `npm run check` | `lint`, then `test`, then `build` |
| `npm run fix` | Applies the automatic fixes |

Every pull request also runs four shared checks: `markdown-lint`,
`link-check`, `actionlint`, and `pr-title`, plus the test check `node-ci`. They are described in
[CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md).

## Environment

None yet. List each variable name here, never its value. Values live in Vercel.

## Deploy

After the owner connects and configures a Vercel project, verify `main` as its
production branch and enable preview protection. The starter does not provision
hosting or prove those settings. Eligible branches and PRs can get previews.

The existing `vercel.json` skips all `dependabot/*` builds, including application
dependency updates, so those PRs have no Vercel preview. CI checks still apply;
record the preview exception in review evidence. See the
[Vercel guidance](https://github.com/alawein/.github/blob/main/docs/vercel.md).

## Contributing

Open an issue first, then a pull request. The rules for branches, commits, and
reviews are in [CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md)
and [delivery rules](https://github.com/alawein/.github/blob/main/docs/system/delivery.md).
Report a vulnerability privately, as described in
[SECURITY](https://github.com/alawein/.github/blob/main/SECURITY.md).

## License

{{license_section}}
