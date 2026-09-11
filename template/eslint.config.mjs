import js from "@eslint/js"
import globals from "globals"

// The app ships JS via import maps (no bundler/build step) — see config/importmap.rb.
// This config only lints app/javascript (Stimulus controllers); e2e/ has its own
// TypeScript setup (tsconfig.json) and isn't part of this surface.
export default [
  js.configs.recommended,
  {
    files: ["app/javascript/**/*.js"],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "module",
      globals: {
        ...globals.browser,
      },
    },
    rules: {
      // Stimulus lifecycle callbacks (e.g. disconnect(event)) often leave params unused.
      "no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
    },
  },
]
