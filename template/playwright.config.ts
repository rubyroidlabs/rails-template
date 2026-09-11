import { defineConfig, devices } from "@playwright/test";

const PORT = process.env.PORT || 3100;
const baseURL = `http://127.0.0.1:${PORT}`;

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: "html",

  use: {
    baseURL,
    trace: "on-first-retry",
  },

  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],

  // Boots a dedicated Rails server in the test environment for the
  // duration of the suite (on a different port than the dev server).
  webServer: {
    command: `RAILS_ENV=test PORT=${PORT} bin/rails server`,
    // Poll the health check route rather than "/" — this app has no root
    // route defined, so "/" 404s forever and never reads as "ready".
    url: `${baseURL}/up`,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
