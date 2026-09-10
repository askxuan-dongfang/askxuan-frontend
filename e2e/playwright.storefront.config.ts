import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests",
  testMatch: "storefront.spec.ts",
  timeout: 30000,
  workers: 2,
  reporter: "list",
  outputDir: "/private/tmp/askxuan-storefront-tests",
  use: { headless: true, trace: "retain-on-failure" },
  webServer: [
    {
      command: "npm run dev -- --host 127.0.0.1 --port 5383",
      cwd: "../apps/web-h5",
      url: "http://127.0.0.1:5383",
      reuseExistingServer: false,
    },
    {
      command:
        "VITE_PUBLIC_BASE=/admin/ npm run dev -- --host 127.0.0.1 --port 5384",
      cwd: "../apps/web-platform-admin",
      url: "http://127.0.0.1:5384/admin/",
      reuseExistingServer: false,
    },
  ],
});
