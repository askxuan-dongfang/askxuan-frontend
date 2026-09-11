import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests', testMatch: '**/community-experience.spec.ts',
  timeout: 45_000, expect: { timeout: 10_000 }, workers: 2,
  reporter: 'list', outputDir: './test-results/community',
  use: { baseURL: 'http://127.0.0.1:5491', trace: 'retain-on-failure' },
  webServer: [...(process.env.CI_ADMIN_ONLY ? [] : [{
    command: 'npm run dev -- --host 127.0.0.1 --port 5491 --strictPort',
    cwd: '../apps/web-h5', url: 'http://127.0.0.1:5491',
    reuseExistingServer: !process.env.CI, timeout: 60_000,
  }]), {
    command: 'npm run dev -- --host 127.0.0.1 --port 5492 --strictPort',
    cwd: '../apps/web-platform-admin', url: 'http://127.0.0.1:5492',
    reuseExistingServer: !process.env.CI, timeout: 60_000,
  }],
});
