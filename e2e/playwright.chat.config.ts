import { defineConfig } from "@playwright/test";
export default defineConfig({
  testDir: "./tests",
  testMatch: "chat-experience.spec.ts",
  timeout: 60000,
  expect: { timeout: 10000 },
  workers: 1,
  reporter: [
    ["list"],
    ["html", { outputFolder: "artifacts/chat-report", open: "never" }],
  ],
  outputDir: "artifacts/chat-results",
  use: {
    baseURL: "http://127.0.0.1:5394",
    headless: true,
    viewport: { width: 430, height: 932 },
    permissions: ["microphone", "camera"],
    launchOptions: {
      args: [
        "--use-fake-device-for-media-stream",
        "--use-fake-ui-for-media-stream",
      ],
    },
    trace: "retain-on-failure",
  },
  webServer: {
    command:
      "npm --prefix ../apps/web-h5 run dev -- --host 127.0.0.1 --port 5394",
    url: "http://127.0.0.1:5394",
    reuseExistingServer: true,
    timeout: 60000,
  },
});
