import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests', testMatch: 'directory.spec.ts',
  timeout: 30_000, expect: { timeout: 10_000 }, workers: 2,
  reporter: 'list', outputDir: './test-results/directory',
  use: { baseURL: 'http://127.0.0.1:5528', trace: 'retain-on-failure' },
  projects: [
    { name: 'directory-320', use: { viewport: { width: 320, height: 740 }, isMobile: true, hasTouch: true } },
    { name: 'directory-390', use: { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } },
    { name: 'directory-768', use: { viewport: { width: 768, height: 1024 } } },
  ],
  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --port 5528 --strictPort',
    cwd: '../apps/web-h5', url: 'http://127.0.0.1:5528',
    reuseExistingServer: false, timeout: 60_000,
  },
});
