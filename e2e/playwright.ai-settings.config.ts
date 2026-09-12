import { defineConfig } from '@playwright/test';
export default defineConfig({
 testDir:'./tests',testMatch:'ai-provider-settings.spec.ts',workers:1,
 timeout:45000,expect:{timeout:10000},reporter:'list',outputDir:'artifacts/ai-settings',
 use:{baseURL:'http://127.0.0.1:5496',viewport:{width:1440,height:1000},trace:'retain-on-failure'},
 webServer:{command:'npm run dev -- --host 127.0.0.1 --port 5496 --strictPort',cwd:'../apps/web-platform-admin',url:'http://127.0.0.1:5496',reuseExistingServer:!process.env.CI,timeout:60000},
});
