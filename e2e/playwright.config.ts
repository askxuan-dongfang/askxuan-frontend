import { defineConfig, devices } from '@playwright/test'

const externalBaseURL = process.env.E2E_LIVE_BASE_URL?.trim().replace(/\/+$/, '')
const liveAuth = process.env.E2E_RUN_LIVE_AUTH === '1'

if (externalBaseURL && !liveAuth) {
  throw new Error('E2E_LIVE_BASE_URL 仅允许与 E2E_RUN_LIVE_AUTH=1 同时使用')
}

export default defineConfig({
  testDir: './tests',
  timeout: 240_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  reporter: [['list'], ['html', { outputFolder: 'artifacts/playwright-report', open: 'never' }]],
  outputDir: 'artifacts/test-results',
  use: {
    trace: 'retain-on-failure',
    actionTimeout: 15_000,
    ignoreHTTPSErrors: Boolean(externalBaseURL)
  },
  projects: [
    {
      name: 'h5-320',
      testMatch: '**/web-h5.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 320, height: 568 }, isMobile: true, hasTouch: true }
    },
    {
      name: 'h5-375',
      testMatch: '**/web-h5.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 375, height: 667 }, isMobile: true, hasTouch: true }
    },
    {
      name: 'h5-390',
      testMatch: '**/web-h5.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true }
    },
    {
      name: 'h5-430',
      testMatch: '**/web-h5.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 430, height: 932 }, isMobile: true, hasTouch: true }
    },
    {
      name: 'h5-768',
      testMatch: '**/web-h5.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 768, height: 1024 } }
    },
    {
      name: 'admin-390',
      testMatch: '**/web-admin.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true }
    },
    {
      name: 'admin-768',
      testMatch: '**/web-admin.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 768, height: 1024 } }
    },
    {
      name: 'admin-1024',
      testMatch: '**/web-admin.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1024, height: 768 } }
    },
    {
      name: 'admin-1280',
      testMatch: '**/web-admin.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1280, height: 800 } }
    },
    {
      name: 'admin-1440',
      testMatch: '**/web-admin.spec.ts',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1000 } }
    },
  ],
  webServer: externalBaseURL ? undefined : [
    {
      command: 'npm run dev -- --host 127.0.0.1 --port 5273',
      cwd: '../apps/web-temple-admin',
      url: 'http://127.0.0.1:5273/login',
      reuseExistingServer: false,
      timeout: 120_000
    },
    {
      command: 'npm run dev -- --host 127.0.0.1 --port 5274',
      cwd: '../apps/web-shop-admin',
      url: 'http://127.0.0.1:5274/login',
      reuseExistingServer: false,
      timeout: 120_000
    },
    {
      command: 'npm run dev -- --host 127.0.0.1 --port 5275',
      cwd: '../apps/web-platform-admin',
      url: 'http://127.0.0.1:5275/login',
      reuseExistingServer: false,
      timeout: 120_000
    },
    {
      command: 'npm run dev -- --host 127.0.0.1 --port 5276',
      cwd: '../apps/web-h5',
      url: 'http://127.0.0.1:5276/c/login',
      reuseExistingServer: false,
      timeout: 120_000
    }
  ]
})
