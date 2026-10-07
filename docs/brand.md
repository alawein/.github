# Brand rules for repo images and READMEs

The default for repos under github.com/alawein follows the owner's site:
a pixel-art night street, the repo name on a red headband ribbon, two palettes
(night and dawn). These rules cover every banner, social preview, logo, and
README. The approved brand source is frozen. Generate repo images only from
that source, and change the source through owner review before regenerating
affected images. The public reuse exception below permits existing approved
bytes without regeneration.

## Default repo images

| File | Size | Use |
| --- | --- | --- |
| `assets/banner-name-night.png` | 1520x600 | README banner, default and dark mode |
| `assets/banner-name-dawn.png` | 1520x600 | README banner, light mode |
| `assets/social-preview.png` | 1280x640, under 1 MB | Link preview card |
| `assets/logo-512.png` | 512x512 | Square mark, favicon or avatar source |

The README embeds the banner pair in a `picture` element at `width="760"`. The
starter is [README.template.md](../templates/README.template.md). It has no H1
because the banner carries the name. Use a text heading when the banner does
not carry a name. Keep artwork committed locally; the narrow badge exception
below permits live workflow status. No badge walls or hosted stats widgets.

## README writing and labels

A README should make the project understandable and usable in its first screen.
Keep the approved Night Market artwork unchanged. Color belongs in a small row
of useful labels or badges, not decorative headings or a wall of technology logos.

### Structure

1. **Identity:** project name, one plain sentence about what it does and who benefits.
2. **At a glance:** two to four relevant labels or badges. Omit anything unverified.
3. **Try it:** the shortest working example, prerequisites, and expected result.
4. **Understand it:** a few capabilities and the limitations that affect real use.
5. **Go deeper:** links to setup, checks, architecture, contribution, and license details.

Adapt the structure to the repository. A profile introduces the person and
selected work, with a clear contact path. A lab states its question and how to
reproduce the result. A docs repository gives readers a short route to its guides.
A private operating workspace links to its actual owners and useful entry points.
Do not add empty sections just to match a template.

### Writing

Use short, connected sentences and active verbs. Lead with the useful outcome,
then explain how it works. Give concrete inputs, outputs, and examples. Prefer
three strong points to an exhaustive feature list. Put implementation detail in
the linked documentation when it interrupts the reader's first use.

Avoid sales adjectives, repeated claims, noun piles, publication lists in personal
introductions, and unsupported authority signals. In the personal profile, lead
with AI systems, scientific computing, mathematical modeling, simulation, and
research software. Research background supports that identity. Keep named papers
and accurate author order in the bibliography, not the profile pitch. Citation
counts and paper counts are not branding badges. Concrete applications are useful.

### Labels, badges, topics, and tags

| Surface | Purpose | Guidance |
| --- | --- | --- |
| README label | Identify a domain, language, or project stage | Use readable text on a restrained solid color; link to relevant evidence or documentation |
| Status badge | Report changing state | Use the actual workflow and default branch; link to the run list, never a hand-painted passing claim |
| Repository topic | Help people discover the project | Choose a small, accurate set for purpose, domain, and language; avoid broad keyword stuffing |
| Issue/PR label | Organize work | Use the existing [canonical labels](../templates/labels.yml); keep useful supplemental labels |
| Git tag | Identify a release | Use version tags for actual releases; never use them as topic keywords |

Use two or three restrained category colors, with white or dark text that stays
legible in both themes. Text must carry the meaning without relying on color.
Give each image concise alt text. Small committed SVG labels are appropriate;
they do not change the frozen banner artwork. Avoid animated cards, visit
counters, citation counters, skill-rating bars, and repeated decorative icons.

A live GitHub Actions badge is an explicit exception to the hosted-widget ban.
Copy the URL from the real workflow, select the default branch, and link the
badge to its run list. A badge reports that workflow's state, not all quality
checks or a security guarantee. Private workflow badges are not public proof.
See [GitHub's badge documentation](https://docs.github.com/en/actions/how-tos/monitor-workflows/add-a-status-badge).

Repository topics are configured on GitHub, not by writing hashtags in a README.
Topic names are public even on private repositories, so keep them free of private
project or client identifiers. See [GitHub's topic documentation](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/classifying-your-repository-with-topics).
A template or local edit does not establish that hosted metadata has changed.

### Starter adoption

The [README template](../templates/README.template.md) and every actual
[starter README](../templates/starters) carry this pattern. Starter category labels
describe the supplied project type, never readiness or test success. Add live
status only after the destination repository and workflow exist. Replace the
starter description with a precise purpose and show the expected first-use result.

## Kit public reuse exception

The owner selected the existing public unlettered night/dawn scene pair for
this kit's README. Copy these bytes without regeneration; this exception
does not change the named-banner default or the frozen generator's `docs`
roofline and monogram selections.

| Placement | Files | Geometry |
| --- | --- | --- |
| Kit README | `assets/banner-night.png`, `assets/banner-dawn.png` | 760x300, displayed at width 760 |
| Profile README | Existing named night/dawn pair | 1520x600, displayed at width 760 |
| Profile social preview and mark | Existing card and square mark | Preserve their identities and bytes |

The kit uses dawn for light mode and night as fallback, paired with the
`.github` text heading because the shared scenes carry no repository name.
Keep the scene alt text plain and identical across themes. Do not relabel an
unlettered scene as a named banner, stretch, smooth, redraw, add glow or neon.
The palettes and art bans below still apply.

The [public asset manifest](../assets/public-assets.json) records all six
approved assets, their roles, dimensions, immutable public source revision,
paths and SHA-256 hashes. Only the two kit scenes are copied here; the named
profile banners, card and mark remain in the source repository.

The kit social preview remains GitHub's generated repository card. Its
760x300 scenes are below GitHub's [recommended preview dimensions](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/customizing-your-repositorys-social-media-preview)
of at least 640x320 (1280x640 for best display). This is rendering guidance,
not a claim of an enforced upload minimum. A selected kit card and its
settings upload are separate owner-approved actions; a committed asset does
not prove upload. The named profile card is not a kit card.

## Palettes

Night is the default. Marketing images (social preview, logo) are always night.

Night:

| Role | Hex |
| --- | --- |
| Ground | `#130b1f` |
| Ink (text) | `#f5ecdf` |
| Ink 2 and ink 3 | `#cbbccb` `#ad9db1` |
| Headband red (ribbon) | `#ce4148` |
| Amber accent | `#ffb454` |
| Ninja suit, eyes | `#40305a` `#ffd08a` |
| Mark disk, ring | `#f5c794` `#8a74a6` |
| Sky ramp | `#0c0718` `#1a1130` `#3d2240` `#6a3645` `#8a4845` `#a85a50` |

Dawn:

| Role | Hex |
| --- | --- |
| Ground (also text on the ribbon) | `#f4f2f7` |
| Ink | `#1a1326` |
| Ink 2 and ink 3 | `#4a4159` `#5c536c` |
| Red (ribbon) | `#c63b3b` |
| Indigo accent | `#2b2877` |
| Sky ramp | `#b3c3e6` `#c8cbec` `#ddd0ea` `#eed3df` `#f8d6c6` `#fbe3b8` |

Neon pink `#ff4fb0` and neon cyan `#3ee6ff` appear only inside the existing
plates. Do not add them anywhere else.

Name contrast on the ribbon, measured with the WCAG ratio:

| Theme | Text on ribbon | Ratio | Meets |
| --- | --- | --- | --- |
| Night | `#f5ecdf` on `#ce4148` | 4.01:1 | AA for large text only |
| Dawn | `#f4f2f7` on `#c63b3b` | 4.62:1 | AA |

The name is always large type (at least 84 px in the image), so 4.01:1 passes
for large text. Never use the night ribbon for body-size text.

## Fonts and licenses

| Font | Weight | Use in images | License |
| --- | --- | --- | --- |
| Literata | 600, optical size 72 | The repo name | SIL OFL 1.1 |
| Libre Franklin | 600 | The tagline on the social preview | SIL OFL 1.1 |
| DotGothic16 | 400 | Shop signs inside the plates only. Never set by hand | SIL OFL 1.1 |

- The OFL allows rendering text into images. The license text travels with any
  font file we keep. We keep font files only in the private generator folder,
  never in a repo.
- The name is set in Literata 600, upright, with no tracking. Never italic.
- Text is drawn as smooth vector outlines over the art. No faux bold.
- The Market Pixel and Market Tube faces are banned outside brand previews.
  Their license is unstated.

## Pixel rules

- One art pixel is 2 CSS pixels. The banner is 380x150 art pixels, drawn at
  4 file pixels each and shown at half width, so it lands on 2 CSS pixels.
- Scale art by whole numbers with nearest neighbor. No smoothing.
- No antialiasing and no dithering in the art. Only text is smooth.
- Art uses palette colors only. The one exception is the sky, a smooth ramp
  between palette colors. Every art pixel is fully opaque.
- Snap the ribbon to whole art pixels. Its notched ends and 1 art pixel outline
  are part of the generator. Do not redraw them by hand.
- Embed with `width="760"` for banners. Do not stretch to a fractional size.

## The name

- Solid color only: ink on the red ribbon. Never a gradient fill, a gradient
  outline, a glow, or a shadow. The name never gets a gradient.
- The name is the repo display name, up to 28 characters, plain ASCII. One
  line, scaled down to fit. Longer names wrap to two lines at a space or
  hyphen. A name that still does not fit is shortened, not squeezed.
- Write it as the repo reads in prose. Do not add a version or a year.

## Banned copy

Never in a banner, tagline, alt text, or README copy:

- job titles the owner has not approved, and company-ownership titles
- career-length claims (a count of years worked)
- prices, rates, or fee ranges
- availability ("open to work", "taking clients")
- "Present" as an end date
- testimonials and client logos
- a phone number
- em dashes (use a comma, a period, or parentheses)

Copy is American English, plain words, sentence case. A tagline says what the
repo does, in one short line.

## Art bans

- Use only the existing plates and marks. Never invent new art. Crops and
  tiling of existing plates are allowed.
- No text in the art layer other than the name and the tagline.
- No charts, stats, logos of other companies, or game chrome (health bars,
  HUD frames).
- No black outlines and no dithering.
- At most three neon elements in view.

## Which plate a repo gets

The generator picks the art by repo kind. Do not override it.

| Kind | Use for | Banner art | Social preview art | Logo |
| --- | --- | --- | --- | --- |
| `site` | Sites and apps | The whole street | The wide street under the sky | Ninja mark |
| `library` | Libraries and packages | Street, centered crop | The wide street under the sky | Ninja mark |
| `lab` | Experiments and research code | Street, left crop | The wide street under the sky | Ninja mark |
| `tool` | CLIs and scripts | The narrow alley, tiled | The narrow alley under the sky | Ninja mark |
| `docs` | Docs and knowledge bases | Roofline under the sky | Roofline under the sky | MA monogram |

The `docs` logo is the owner's "MA" monogram tile from the site.

## Alt text

- The banner `img` carries the alt text. The `source` element does not.
- Start with the name exactly as written on the ribbon, then one short phrase
  for the scene: `Repo name, on a red ribbon over a pixel-art street at night
  with lit shop windows`.
- Plain words, under about 125 characters. No "image of" or "banner of".
- Do not repeat the tagline or add keywords.
- A logo used inline gets `Repo name logo`. A purely decorative image gets an
  empty `alt=""` and must sit next to text that names the repo.
- Keep the same alt for night and dawn. They show the same scene.

## Social preview

Upload `assets/social-preview.png` by hand in the repo: Settings, General,
Social preview, Edit, Upload an image. GitHub does not read it from the repo
and there is no documented API route for it, so the upload is a manual step.
Keep the file in `assets/` as the record. It must be 1280x640 and under 1 MB.

## Making the images

The generator is private because it reads the owner's site code, brand tokens,
plates, and font files. It is not in this repo and never goes into a public
repo. Command:

```text
node repo-assets.mjs <site repo> <out folder> --name "<display name>" --kind <site|library|lab|tool|docs> [--tagline "text"] [--check]
```

- `<site repo>` is the owner's checkout of the site. The generator only reads
  it.
- `--name` is the display name (28 characters at most). `--tagline` is
  optional and only appears on the social preview.
- Output is deterministic: the same inputs give the same bytes.
- A lock file beside the generator records source and output hashes for each
  name and kind. `--check` rebuilds in memory and reports any drift from the
  files in `<out folder>` and from the lock.
- It stops with a message if the name does not fit, a character has no glyph,
  the tagline is too long, banned copy appears, any art pixel is off palette,
  text gets too close to the ribbon edge, name contrast drops under 3:1, or the
  social preview reaches 1 MB. It prints the WCAG ratio for each image.

Then:

1. Open all four PNGs and look at them. Nothing clipped, nothing off brand.
2. Copy them to `assets/` in the repo.
3. Fill in the README from the template.
4. Run the markdown lint and link check before the pull request.
5. Upload the social preview in the repo settings (see above).
6. After an owner-approved brand source change, run `--check` for every repo
   and regenerate only the images that drift.
