import { defineConfig } from '@playwright/test';
export default defineConfig({
 testDir:'./tests',testMatch:'ai-model-selection.spec.ts',workers:1,
 timeout:45000,expect:{timeout:10000},reporter:'list',outputDir:'artifacts/ai-models',
 use:{baseURL:'http://127.0.0.1:5395',viewport:{width:390,height:900},trace:'retain-on-failure'},
 webServer:{command:'npm run dev -- --host 127.0.0.1 --port 5395 --strictPort',cwd:'../apps/web-h5',url:'http://127.0.0.1:5395',reuseExistingServer:!process.env.CI,timeout:60000},
});
