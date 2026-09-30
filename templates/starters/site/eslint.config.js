import js from "@eslint/js";
import tseslint from "typescript-eslint";

// ESLint covers the TypeScript files. `astro check` covers the .astro files.
export default [
  { ignores: ["dist", ".astro", ".vercel", "node_modules", "**/*.astro"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
];
