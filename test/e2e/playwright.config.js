import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: ".",
  testMatch: "*.spec.js",
  timeout: 60_000,
  expect: { timeout: 10_000 },
  retries: 1,
  use: {
    baseURL: process.env.BASE_URL || "http://localhost:4000",
    actionTimeout: 5_000,
    viewport: { width: 1280, height: 800 },
  },
  reporter: [["html", { open: "never" }], ["list"]],
  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
});
