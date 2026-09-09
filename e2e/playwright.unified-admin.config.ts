import { defineConfig } from '@playwright/test'
export default defineConfig({
 testDir: './tests', testMatch: 'unified-admin.spec.ts', timeout: 45000, workers: 3,
 reporter: 'list', outputDir: '/private/tmp/askxuan-unified-admin-tests',
 use: { headless: true, actionTimeout: 10000, trace: 'retain-on-failure' },
 webServer: { command: 'python3 fixtures/admin-modal-server.py', url: 'http://127.0.0.1:5388/admin/login', reuseExistingServer: true }
})
