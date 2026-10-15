import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: 'wallet.spec.ts',
  timeout: 45_000,
  workers: 1,
  reporter: 'list',
  outputDir: '/private/tmp/askxuan-wallet-playwright',
  use: { baseURL: 'http://127.0.0.1:5396', headless: true, trace: 'retain-on-failure' },
  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --port 5396',
    cwd: '../apps/web-h5',
    url: 'http://127.0.0.1:5396',
    reuseExistingServer: false,
  },
});
