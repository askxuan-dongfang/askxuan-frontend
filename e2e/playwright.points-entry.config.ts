import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests', testMatch: 'points-entry.spec.ts',
  timeout: 30_000, expect: { timeout: 10_000 }, workers: 2,
  reporter: 'list', outputDir: './test-results/points-entry',
  use: { baseURL: 'http://127.0.0.1:5517', trace: 'retain-on-failure' },
  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --port 5517 --strictPort',
    cwd: '../apps/web-h5', url: 'http://127.0.0.1:5517',
    reuseExistingServer: false, timeout: 60_000,
  },
});
