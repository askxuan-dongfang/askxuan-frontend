import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests', testMatch: 'h5-review-regressions.spec.ts',
  timeout: 45_000, expect: { timeout: 10_000 }, workers: 1,
  reporter: 'list', outputDir: './test-results/h5-review',
  use: { baseURL: 'http://127.0.0.1:5589', viewport: { width: 390, height: 844 }, trace: 'retain-on-failure',
    launchOptions: { args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] } },
  webServer: { command: 'npm run dev -- --host 127.0.0.1 --port 5589 --strictPort', cwd: '../apps/web-h5', url: 'http://127.0.0.1:5589', reuseExistingServer: false, timeout: 60_000 },
});
