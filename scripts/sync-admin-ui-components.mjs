import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const write = process.argv.includes('--write')
const check = process.argv.includes('--check')

if (write === check) {
  console.error('用法: node scripts/sync-admin-ui-components.mjs --write|--check')
  process.exit(2)
}

const targets = {
  'PageHeader.vue': ['web-platform-admin', 'web-shop-admin', 'web-temple-admin'],
  'StatusTag.vue': ['web-platform-admin', 'web-shop-admin', 'web-temple-admin'],
  'StatCard.vue': ['web-platform-admin', 'web-shop-admin', 'web-temple-admin'],
  'DataTable.vue': ['web-platform-admin', 'web-temple-admin'],
  'ImageUploader.vue': ['web-platform-admin', 'web-shop-admin', 'web-temple-admin']
}

const drift = []

for (const [component, apps] of Object.entries(targets)) {
  const sourcePath = resolve(root, 'packages/admin-ui/components', component)
  const source = readFileSync(sourcePath, 'utf8')

  for (const app of apps) {
    const targetPath = resolve(root, 'apps', app, 'src/components', component)
    if (write) {
      writeFileSync(targetPath, source)
      console.log(`同步 ${component} -> ${app}`)
      continue
    }

    let target = ''
    try {
      target = readFileSync(targetPath, 'utf8')
    } catch {
      drift.push(`${app}/${component} 缺失`)
      continue
    }
    if (target !== source) drift.push(`${app}/${component} 与共享源不一致`)
  }
}

if (drift.length > 0) {
  console.error(drift.join('\n'))
  console.error('运行 node scripts/sync-admin-ui-components.mjs --write 后重试。')
  process.exit(1)
}

if (check) console.log('管理台共享组件镜像: 全部一致')
