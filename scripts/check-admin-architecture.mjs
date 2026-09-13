import assert from 'node:assert/strict'
import { existsSync, readdirSync, readFileSync } from 'node:fs'
import { dirname, resolve, relative } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const platform = resolve(root, 'apps/web-platform-admin')
const require = createRequire(resolve(platform, 'package.json'))
const ts = require('typescript')
const read = path => readFileSync(resolve(root, path), 'utf8')
const contract = JSON.parse(read('scripts/commerce-routes.json'))
const apiModules = JSON.parse(read('scripts/commerce-api-modules.json'))
const platformPaths = JSON.parse(read('scripts/platform-routes.json'))
const routeFile = resolve(platform, 'src/commerce/routes.ts')
const routeSource = readFileSync(routeFile, 'utf8')
// Loading this route table creates lazy import functions without loading Vue or rendering pages.
const module = ts.transpileModule(routeSource, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText
const { commerceRoutes } = await import('data:text/javascript;base64,' + Buffer.from(module).toString('base64'))
assert.equal(contract.length, 17, 'Commerce coverage contract must include 17 routes')
assert.equal(commerceRoutes.length, 17, 'All commerce routes must remain registered')
assert.equal(new Set(commerceRoutes.map(route => route.path)).size, 17, 'Duplicate commerce paths')
for (const expected of contract) {
  const route = commerceRoutes.find(route => '/' + route.path === expected.path)
  assert.ok(route, `Missing commerce route ${expected.path}`)
  assert.equal(route.name, expected.name)
  assert.equal(route.meta.title, expected.title)
  assert.deepEqual(route.meta.roles, ['shop_admin', 'platform_super'], `Incorrect commerce audience: ${expected.path}`)
  assert.ok(route.component.toString().includes(`./views/${expected.view}`), `Wrong local component: ${expected.path}`)
  assert.ok(existsSync(resolve(platform, 'src/commerce/views', expected.view)), `Missing view: ${expected.view}`)
}
assert.equal(apiModules.length, 8)
assert.deepEqual(readdirSync(resolve(platform, 'src/commerce/api')).filter(name => name.endsWith('.ts')).sort(), [...apiModules].sort(), 'Commerce API module coverage changed')

const routerSource = readFileSync(resolve(platform, 'src/router/index.ts'), 'utf8')
const routerAst = ts.createSourceFile('router.ts', routerSource, ts.ScriptTarget.Latest, true)
const registeredPaths = []
let commerceImported = false, commerceSpread = false
function visit(node) {
  if (ts.isImportDeclaration(node) && node.moduleSpecifier.text === '@/commerce/routes') {
    commerceImported = Boolean(node.importClause?.namedBindings?.elements?.some(item => item.name.text === 'commerceRoutes'))
  }
  if (ts.isSpreadElement(node) && node.expression.getText(routerAst) === 'commerceRoutes') commerceSpread = true
  if (ts.isPropertyAssignment(node) && node.name.getText(routerAst) === 'path' && ts.isStringLiteral(node.initializer)) registeredPaths.push('/' + node.initializer.text.replace(/^\//, ''))
  ts.forEachChild(node, visit)
}
visit(routerAst)
assert.ok(commerceImported && commerceSpread, 'Unified router must register the local commerce route table')
for (const path of platformPaths) assert.ok(registeredPaths.includes(path), `Missing platform route: ${path}`)

function walk(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(item => item.isDirectory() ? walk(resolve(dir, item.name)) : [resolve(dir, item.name)])
}
let checked = 0
for (const file of [...walk(resolve(platform, 'src')), resolve(platform, 'vite.config.ts')]) {
  if (!/\.(?:[cm]?[jt]sx?|vue|css)$/.test(file) || file.endsWith('.test.mjs')) continue
  const source = readFileSync(file, 'utf8')
  for (const match of source.matchAll(/(?:\bfrom\s*|\bimport\s*(?:\(\s*)?|@import\s*)['"]([^'"]+)['"]/g)) {
    const specifier = match[1]
    assert.ok(!specifier.includes('web-shop-admin'), `Retired app import: ${relative(root, file)}`)
    if (specifier.startsWith('.')) {
      const resolved = resolve(dirname(file), specifier)
      const appRelative = relative(resolve(root, 'apps'), resolved)
      if (!appRelative.startsWith('..')) assert.ok(resolved.startsWith(platform + '/'), `Cross-app source import: ${relative(root, file)} -> ${specifier}`)
    }
    checked++
  }
}
assert.ok(!existsSync(resolve(root, 'apps/web-shop-admin')), 'The standalone shop application must not return')
// Vue and TypeScript aliases may reference shared packages, never another application tree.
for (const file of ['vite.config.ts', 'tsconfig.json', 'tsconfig.node.json', 'package.json']) {
  assert.ok(!readFileSync(resolve(platform, file), 'utf8').includes('web-shop-admin'), `Retired app dependency in ${file}`)
}
console.log(`Unified admin architecture: 17 commerce routes, 8 API modules, ${platformPaths.length} platform routes, ${checked} imports checked; no cross-app source dependency`)
