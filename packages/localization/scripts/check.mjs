import { readFileSync, existsSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import assert from 'node:assert/strict'
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../..')
const catalog = JSON.parse(readFileSync(path.join(root, 'packages/localization/zh-Hant.json'), 'utf8'))
for (const [key, value] of Object.entries(catalog)) {
  assert.equal(typeof value, 'string', key)
  assert.ok(value.length, key)
}
assert.equal(catalog['语言'], '語言')
assert.equal(catalog['跟随系统'], '跟隨系統')
const h5 = path.join(root, 'apps/web-h5/src/i18n')
if (existsSync(h5)) {
  assert.deepEqual(JSON.parse(readFileSync(path.join(h5, 'zh-Hant.json'), 'utf8')), catalog, 'H5 traditional Chinese catalog mirror drift')
}
console.log(`Localization catalog: ${Object.keys(catalog).length} translations; available H5 mirrors match`)
