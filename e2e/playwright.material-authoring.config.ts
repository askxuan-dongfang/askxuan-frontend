import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir: './tests', testMatch: 'material-authoring.spec.ts', timeout: 60000, workers: 2,
  reporter: 'list', outputDir: './test-results/material-authoring',
  use: { headless: true, actionTimeout: 10000, trace: 'retain-on-failure', launchOptions: { args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] } },
  webServer: { command: 'python3 fixtures/admin-modal-server.py', url: 'http://127.0.0.1:5388/admin/login', reuseExistingServer: false }
})
