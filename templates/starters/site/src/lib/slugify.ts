/** Turn a title into a URL-safe slug. Pure logic like this lives in src/lib and is tested. */
export function slugify(text: string): string {
  return text
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
