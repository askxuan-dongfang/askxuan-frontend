import { defineConfig } from '@playwright/test'
export default defineConfig({
 testDir:'./tests',testMatch:'overlay-position.spec.ts',timeout:45000,workers:1,
 reporter:'list',outputDir:'artifacts/overlay-position',
 use:{headless:true,trace:'retain-on-failure'},
 webServer:{command:'python3 fixtures/admin-modal-server.py',url:'http://127.0.0.1:5388/admin/login',reuseExistingServer:false}
})
