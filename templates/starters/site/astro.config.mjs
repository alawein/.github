import { defineConfig } from "astro/config";

// Set `site` to the production URL once the domain is attached.
export default defineConfig({
  site: "https://{{name}}.vercel.app",
});
