import {defineConfig} from '@playwright/test'
if(!process.env.E2E_LIVE_BASE_URL) throw new Error('Set an explicitly authorized ECS URL')
export default defineConfig({testDir:'./tests',testMatch:'unified-live.spec.ts',timeout:180000,workers:1,reporter:'list',outputDir:'/private/tmp/askxuan-unified-live',use:{baseURL:process.env.E2E_LIVE_BASE_URL,ignoreHTTPSErrors:true,headless:true,actionTimeout:15000,trace:'off'}})
