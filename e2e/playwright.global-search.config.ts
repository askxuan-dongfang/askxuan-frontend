import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests', testMatch: 'global-search.spec.ts',
  timeout: 30_000, expect: { timeout: 10_000 }, workers: 2,
  reporter: 'list', outputDir: './test-results/global-search',
  use: { baseURL: 'http://127.0.0.1:5529', trace: 'retain-on-failure' },
  projects: [
    { name: 'global-search-390', use: { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } },
    { name: 'global-search-768', use: { viewport: { width: 768, height: 1024 } } },
  ],
  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --port 5529 --strictPort',
    cwd: '../apps/web-h5', url: 'http://127.0.0.1:5529',
    reuseExistingServer: false, timeout: 60_000,
  },
});
