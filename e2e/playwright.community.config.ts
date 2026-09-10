import { defineConfig } from '@playwright/test';
export default defineConfig({ testDir: './tests', testMatch: '**/community-experience.spec.ts', timeout: 45_000, expect: { timeout: 10_000 }, workers: 2, reporter: 'list', outputDir: '/private/tmp/askxuan-community-20260911/test-results', use: { baseURL: 'http://127.0.0.1:5491', trace: 'retain-on-failure' } });
