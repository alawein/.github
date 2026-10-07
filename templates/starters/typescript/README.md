<!-- Add assets/banner-name-night.png and assets/banner-name-dawn.png (see the brand doc in alawein/.github), then delete the banner line in .lycheeignore. -->
<picture>
  <source media="(prefers-color-scheme: light)" srcset="assets/banner-name-dawn.png">
  <img src="assets/banner-name-night.png" alt="{{display_name}}, on a red ribbon over a pixel-art street at night with lit shop windows" width="760">
</picture>

{{description}}

![Project category: TypeScript](assets/project-label.svg)

<!-- Follow the README writing and labels section in alawein/.github/docs/brand.md. Add only useful labels or verified live badges. -->

## Quick start

```sh
npm install
npm run check
```

`npm install` also writes `package-lock.json`. Commit it: CI installs from it.
When it works, `npm run check` ends with no errors and `dist/` holds the build.

```ts
import { greet } from "{{name}}";

greet("world"); // "hello, world"
```

## Checks

| Task | What it does |
| --- | --- |
| `npm run lint` | ESLint, Prettier, and the type check. Changes nothing |
| `npm test` | Runs the tests with Vitest |
| `npm run build` | Compiles `src/` into `dist/` |
| `npm run check` | `lint`, then `test`, then `build` |
| `npm run fix` | Applies the automatic fixes |

Every pull request also runs four shared checks: `markdown-lint`,
`link-check`, `actionlint`, and `pr-title`, plus the test check `node-ci`. They are described in
[CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md).

## Contributing

Open an issue first, then a pull request. The rules for branches, commits, and
reviews are in [CONTRIBUTING](https://github.com/alawein/.github/blob/main/CONTRIBUTING.md)
and [delivery rules](https://github.com/alawein/.github/blob/main/docs/system/delivery.md).
Report a vulnerability privately, as described in
[SECURITY](https://github.com/alawein/.github/blob/main/SECURITY.md).

## License

{{license_section}}
