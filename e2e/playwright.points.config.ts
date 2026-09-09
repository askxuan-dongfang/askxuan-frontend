import { defineConfig } from '@playwright/test'
export default defineConfig({
  testDir:'./tests', testMatch:'points.spec.ts', timeout:60000, workers:1, expect:{timeout:20000},
  reporter:'list', outputDir:'/private/tmp/askxuan-points-playwright',
  use:{headless:true,trace:'retain-on-failure'},
  webServer:[
    {command:'npm run dev -- --host 127.0.0.1 --port 5376',cwd:'../apps/web-h5',url:'http://127.0.0.1:5376',timeout:120000,reuseExistingServer:false},
    {command:'npm run dev -- --host 127.0.0.1 --port 5374',cwd:'../apps/web-platform-admin',url:'http://127.0.0.1:5374',timeout:120000,reuseExistingServer:false},
  ],
})
