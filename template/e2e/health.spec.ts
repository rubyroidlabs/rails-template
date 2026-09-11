import { test, expect } from "@playwright/test";

test("health check endpoint is up", async ({ page }) => {
  const response = await page.goto("/up");

  expect(response?.status()).toBe(200);
});
