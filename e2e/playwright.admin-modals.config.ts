import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: './tests', testMatch: 'admin-modals.spec.ts', timeout: 45000, workers: 1,
  reporter: 'list', outputDir: '/private/tmp/askxuan-admin-modal-tests',
  use: { headless: true, trace: 'retain-on-failure' },
  // Build all three admin apps before running this static-production regression.
  webServer: { command: 'python3 fixtures/admin-modal-server.py', url: 'http://127.0.0.1:5388/shop/login', reuseExistingServer: true }
})
