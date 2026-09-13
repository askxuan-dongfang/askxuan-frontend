import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'
import { legacyShopDocument, runLegacyShop } from './legacy-shop.mjs'

const routes = JSON.parse(readFileSync(new URL('../../../../scripts/commerce-routes.json', import.meta.url)))
function browser(path, values = {}) {
  const url = new URL(path, 'https://example.test')
  const data = new Map(Object.entries(values)), calls = []
  const scope = {
    location: { origin: url.origin, pathname: url.pathname, search: url.search, hash: url.hash, replace: value => calls.push(value) },
    localStorage: { getItem: key => data.get(key) ?? null, setItem: (key, value) => data.set(key, value), removeItem: key => data.delete(key) },
    document: { documentElement: { dataset: {} } },
    matchMedia: () => ({ matches: false })
  }
  return { scope, data, calls }
}

for (const entry of routes) test(`legacy route ${entry.legacy} preserves query, fragment and one redirect`, () => {
  const path = entry.legacy.replace('/:id?', '/42').replace('/:id', '/42')
  const { scope, calls } = browser(path + '?page=2&filter=%E5%BE%85%E5%8F%91%E8%B4%A7#record')
  runLegacyShop(scope)
  assert.deepEqual(calls, ['https://example.test/admin' + path.replace(/^\/shop/, '/commerce') + '?page=2&filter=%E5%BE%85%E5%8F%91%E8%B4%A7#record'])
})
test('root bookmarks and login redirects map to current router paths', () => {
  for (const path of ['/shop', '/shop/']) assert.equal(runLegacyShop(browser(path).scope), 'https://example.test/admin/commerce/dashboard')
  for (const redirect of ['/orders/9?tab=items#row', '/shop/orders/9?tab=items#row', '/commerce/orders/9?tab=items#row', '/admin/commerce/orders/9?tab=items#row']) {
    const url = new URL(runLegacyShop(browser('/shop/login?redirect=' + encodeURIComponent(redirect) + '&page=2#login').scope))
    assert.equal(url.pathname, '/admin/login')
    assert.equal(url.searchParams.get('redirect'), '/commerce/orders/9?tab=items#row')
    assert.equal(url.searchParams.get('page'), '2')
    assert.equal(url.hash, '#login')
  }
  const search = new URL(runLegacyShop(browser('/shop/login?redirect=' + encodeURIComponent('/orders?keyword=two words')).scope))
  assert.equal(search.searchParams.get('redirect'), '/commerce/orders?keyword=two%20words')
})
test('unsafe redirect values are discarded and cannot change origin', () => {
  for (const redirect of ['https://evil.test', '//evil.test', '/\\evil.test', 'javascript:alert(1)', '\n//evil.test', 'orders/1']) {
    const url = new URL(runLegacyShop(browser('/shop/login?redirect=' + encodeURIComponent(redirect) + '&redirect=%2Forders%2F1').scope))
    assert.equal(url.origin, 'https://example.test')
    assert.equal(url.pathname, '/admin/login')
    assert.equal(url.searchParams.has('redirect'), false)
  }
})
test('dev server uses its own root and keeps encoded IDs intact', () => {
  assert.equal(runLegacyShop(browser('/shop/orders/a%2Fb?x=1#r').scope, '/'), 'https://example.test/commerce/orders/a%2Fb?x=1#r')
})
test('legacy identity transfers all credentials and removes the old namespace', () => {
  const values = Object.fromEntries(['token', 'refresh_token', 'user', 'session_id'].map(s => [`df_shop_admin_${s}`, 'legacy-' + s]))
  const { scope, data } = browser('/shop/orders', values)
  runLegacyShop(scope)
  for (const suffix of ['token', 'refresh_token', 'user', 'session_id']) {
    assert.equal(data.get(`df_platform_admin_${suffix}`), 'legacy-' + suffix)
    assert.equal(data.has(`df_shop_admin_${suffix}`), false)
  }
})
test('current unified identity wins and missing legacy values cannot reuse stale credentials', () => {
  const existing = { df_platform_admin_token: 'current', df_platform_admin_refresh_token: 'current-refresh', df_shop_admin_token: 'old', df_shop_admin_user: 'old-user' }
  const active = browser('/shop/products', existing)
  runLegacyShop(active.scope)
  assert.equal(active.data.get('df_platform_admin_token'), 'current')
  assert.equal(active.data.get('df_platform_admin_refresh_token'), 'current-refresh')
  assert.equal(active.data.has('df_platform_admin_user'), false)
  assert.equal(active.data.has('df_shop_admin_token'), false)
  const stale = browser('/shop/products', { df_shop_admin_token: 'old', df_platform_admin_refresh_token: 'unrelated', df_platform_admin_user: 'unrelated', df_platform_admin_session_id: 'unrelated' })
  runLegacyShop(stale.scope)
  assert.equal(stale.data.get('df_platform_admin_token'), 'old')
  for (const suffix of ['refresh_token', 'user', 'session_id']) assert.equal(stale.data.has(`df_platform_admin_${suffix}`), false)
})
test('incomplete storage transfer rolls back and retains legacy credentials', () => {
  const fixture = browser('/shop/orders', { df_shop_admin_token: 'old', df_shop_admin_user: 'old-user', df_platform_admin_user: 'prior-user' })
  const write = fixture.scope.localStorage.setItem
  fixture.scope.localStorage.setItem = (key, value) => { if (key === 'df_platform_admin_token') throw new Error('quota'); write(key, value) }
  runLegacyShop(fixture.scope)
  assert.equal(fixture.data.get('df_shop_admin_token'), 'old')
  assert.equal(fixture.data.get('df_platform_admin_user'), 'prior-user')
  assert.equal(fixture.data.has('df_platform_admin_token'), false)
  assert.equal(fixture.calls.length, 1)
})
test('blocked storage and anonymous bookmarks still reach the unified login flow', () => {
  const fixture = browser('/shop/login')
  Object.defineProperty(fixture.scope, 'localStorage', { get() { throw new Error('blocked') } })
  assert.equal(runLegacyShop(fixture.scope), 'https://example.test/admin/login')
  assert.equal(runLegacyShop(browser('/shop/orders').scope), 'https://example.test/admin/commerce/orders')
})
test('generated HTML executes the real shim standalone and honors appearance preference', () => {
  const html = legacyShopDocument(), fixture = browser('/shop/orders/9?x=1#row', { 'askxuan-theme': 'dark' })
  assert.equal(/<script[^>]+src=|<link[^>]+href=/.test(html), false)
  const script = html.match(/<script>([\s\S]+)<\/script>/)?.[1]
  assert.ok(script)
  vm.runInNewContext(script, { window: fixture.scope, URL, URLSearchParams })
  assert.deepEqual(fixture.calls, ['https://example.test/admin/commerce/orders/9?x=1#row'])
  assert.equal(fixture.scope.document.documentElement.dataset.theme, 'dark')
  for (const base of ['https://evil.test/', '//evil.test/', '/admin', '/</script>/']) assert.throws(() => legacyShopDocument(base))
})
