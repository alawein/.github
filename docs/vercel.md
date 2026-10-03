# Vercel domain moves

The runbook for moving a production domain between Vercel projects, and the
`vercel.json` template. The rules for Vercel in general (one scope, protection,
environment variables, rollback) are in
[delivery.md](system/delivery.md), "Vercel". Only the site class uses Vercel.

## vercel.json template

Copy it, replace `example.com`, and delete what the site does not need. It sets
clean URLs, no trailing slash, three security headers, a `www` redirect that
starts as temporary (307), and a skip for Dependabot builds.

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "cleanUrls": true,
  "trailingSlash": false,
  "ignoreCommand": "case \"$VERCEL_GIT_COMMIT_REF\" in dependabot/*) exit 0;; *) exit 1;; esac",
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
        { "key": "X-Frame-Options", "value": "DENY" }
      ]
    }
  ],
  "redirects": [
    {
      "source": "/:path*",
      "has": [{ "type": "host", "value": "www.example.com" }],
      "destination": "https://example.com/:path*",
      "permanent": false
    }
  ]
}
```

- `permanent: false` gives a 307. Vercel defaults to 308, and browsers cache 308
  and 301 answers, so a wrong one cannot be recalled. Move to 308 only after 7
  clean days (step 6 below).
- The existing `ignoreCommand` skips every `dependabot/*` branch, including npm
  and other application dependency updates, not just workflow-only updates.
  Exit 0 ignores the build; exit 1 continues it. These PRs have no preview,
  so record the exception and retain CI checks. Any skip-policy change needs
  a separate proposal. See [Vercel's reference](https://vercel.com/docs/project-configuration/vercel-json#ignorecommand).
- Copying this file does not connect a Vercel project or enable protection.
  Verify the configured production branch and preview protection after setup.
- A branch-scoped domain such as `staging.example.com` can point at one preview
  branch. It stays behind protection, so an unfinished site is not public.

## Move a production domain to a new project

Use this when a new site replaces an old one on the same domain, inside the one
scope. A move inside a scope needs no DNS change and no ownership check.

1. Save baselines: DNS records for the apex and `www`, the HTTP status of the
   apex, `www`, and about ten old URLs, the certificate expiry, and the
   redirect the old project uses today. Export the DNS zone to a file outside
   the repo. Record where the old project's redirect lives.
2. In the new project, add the apex and `www` and confirm Move Domain. Do not
   remove them from the old project first: that can interrupt traffic. Do not
   use `vercel domains rm`: it removes the domain from the whole scope.
3. Make the apex primary. Make `www` redirect to it with status 307.
4. Probe at once: the apex answers 200, and `www/x` answers 307 to `/x`.
5. Leave DNS and any proxy setting alone. Check the certificate covers the apex
   and `www`, and that the mail and TXT records still equal the baseline.
6. After 7 clean days, change the `www` redirect to 308 and check again. Then
   protect the old project's deployments. At least 7 days later, record the
   old project's env variable names (names only) and settings, and delete it.

Roll back before step 6: move both domains back to the old project, restore its
old redirect, and change no DNS record except one that was edited by hand
(restore only that record, never import a whole zone). A 308 that a browser
already cached cannot be recalled, which is why step 6 waits.

Stop and do not proceed if: a gate is red, a domain ownership prompt appears
(it means a move across accounts), the certificate does not show valid for the
apex and `www`, protection is All Deployments, or the mail records changed.

## What never to do

- Never remove a domain from the old project before adding it to the new one.
- Never run `vercel domains rm` to move a domain.
- Never switch a redirect to 308 or 301 before 7 clean days.
- Never import a whole DNS zone file to undo a change.
- Never delete the old project before the new one has served the domain for 7
  clean days and its settings are recorded.
- Never set protection to All Deployments on a project with a public domain, and
  never disable protection "just to test". Use the bypass secret.
