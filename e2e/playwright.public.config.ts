import { defineConfig, devices } from '@playwright/test'

const publicBaseURL = process.env.E2E_PUBLIC_BASE_URL?.trim().replace(/\/+$/, '')

if (!publicBaseURL || !/^https?:\/\//.test(publicBaseURL)) {
  throw new Error('公开 ECS 验收必须显式设置 E2E_PUBLIC_BASE_URL，且不会读取或提交任何登录凭证')
}

export default defineConfig({
  testDir: './tests',
  testMatch: '**/web-public.spec.ts',
  timeout: 180_000,
  expect: { timeout: 12_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [['list'], ['html', { outputFolder: 'artifacts/playwright-public-report', open: 'never' }]],
  outputDir: 'artifacts/public-test-results',
  use: {
    baseURL: publicBaseURL,
    trace: 'retain-on-failure',
    actionTimeout: 15_000,
    ignoreHTTPSErrors: true
  },
  projects: [
    {
      name: 'public-320',
      use: { ...devices['Desktop Chrome'], viewport: { width: 320, height: 568 }, isMobile: true, hasTouch: true }
    },
    {
      name: 'public-390',
      use: { ...devices['Desktop Chrome'], viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true }
    },
    {
      name: 'public-768',
      use: { ...devices['Desktop Chrome'], viewport: { width: 768, height: 1024 } }
    },
    {
      name: 'public-1440',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 1000 } }
    }
  ]
})
