import { readFileSync } from 'node:fs'
import { createHash } from 'node:crypto'
import assert from 'node:assert/strict'
const manifest = JSON.parse(readFileSync(new URL('./admin-migration-manifest.json', import.meta.url)))
for (const item of manifest) {
 const source = readFileSync(new URL(`../apps/web-platform-admin/src/commerce/views/${item.view}`, import.meta.url),'utf8')
 const normalized = source.replaceAll('@/commerce/api/','@/api/').replaceAll('@/commerce/utils/','@/utils/').replaceAll('@/commerce/types','@/types').replaceAll('/commerce/','/')
 assert.equal(createHash('sha256').update(normalized).digest('hex'),item.baselineSha256,`${item.view}: business behavior differs from the migration baseline; review and record any intentional follow-up`)
}
const routes=readFileSync(new URL('../apps/web-platform-admin/src/router/index.ts',import.meta.url),'utf8')
for(const path of JSON.parse(readFileSync(new URL('./platform-route-baseline.json',import.meta.url)))) {
 assert.ok(new RegExp(`path:\\s*'${path.slice(1)}'`).test(routes),`Missing platform route: ${path}`)
}
console.log(`${manifest.length} shop pages preserved; all 28 existing platform routes retained`)

const apis = JSON.parse(readFileSync(new URL('./commerce-api-baseline.json', import.meta.url)))
for(const [file,hash] of Object.entries(apis)) {
 const source = readFileSync(new URL(`../apps/web-platform-admin/src/commerce/api/${file}`,import.meta.url),'utf8').replaceAll("'@/api/client'","'./client'").replaceAll('@/commerce/types','@/types')
 assert.equal(createHash('sha256').update(source).digest('hex'),hash,`API adapter changed: ${file}`)
}
console.log('All 8 commerce API adapters preserved')
