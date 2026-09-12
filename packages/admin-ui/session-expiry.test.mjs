import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { stripTypeScriptTypes } from 'node:module'
import test from 'node:test'
import vm from 'node:vm'

const source = stripTypeScriptTypes(await readFile(new URL('./session-expiry.ts', import.meta.url), 'utf8'), { mode: 'strip' }).replace(/\bexport /g, '')
const context = vm.createContext({})
vm.runInContext(source + '\nthis.guard = createAdminSessionGuard; this.failure = isSessionFailure; this.publicEndpoint = isAuthenticationEndpoint;', context)
const prefix = 'df_temple_admin'
function setup({ token = 'old-token', refreshToken, refresh = async () => null, pathname = '/temple/report' } = {}) {
  const values = new Map([[`${prefix}_token`, token], [`${prefix}_user`, '{"id":"test"}'], [`${prefix}_temple_id`, 'test-temple'], [`${prefix}_temple_name`, 'Test'], [`${prefix}_session_id`, 'session-a'], ['df_platform_admin_token', 'other-session']])
  if (!token) values.delete(`${prefix}_token`)
  if (refreshToken) values.set(`${prefix}_refresh_token`, refreshToken)
  const events = { expired: 0, refreshed: 0, refresh: 0, redirects: [] }
  const storage = { getItem: key => values.get(key) || null, removeItem: key => values.delete(key), setItem: (key, value) => values.set(key, value) }
  const guard = context.guard({ prefix, baseUrl: '/temple/', storage, location: { pathname, search: '?range=month', hash: '#trend', replace: path => events.redirects.push(path) }, invalidate: () => events.expired++, refreshed: () => events.refreshed++, refresh: async value => { events.refresh++; return refresh(value) } })
  return { guard, values, events }
}
const recover = (env, snapshot, code = 40102, retried = false, status = 200, url = '/admin/bookings/report') => env.guard.recover(snapshot, url, status, code, retried)

test('all gateway session codes clear only their own complete session and navigate once when no refresh exists', async () => {
  for (const code of [40101, 40102, 40103, '40102']) {
    const env = setup(); const snapshot = env.guard.capture('/admin/bookings/report')
    const results = await Promise.all(Array.from({ length: 5 }, () => recover(env, snapshot, code)))
    assert.equal(results[0].kind, 'expired')
    assert.equal(env.events.expired, 1)
    assert.equal(env.events.redirects.length, 1)
    assert.equal(env.events.redirects[0], '/temple/login?redirect=%2Freport%3Frange%3Dmonth%23trend')
    assert.equal([...env.values.keys()].filter(key => key.startsWith(prefix)).length, 0)
    assert.equal(env.values.get('df_platform_admin_token'), 'other-session')
    assert.throws(() => env.guard.capture('/admin/bookings'), { name: 'AdminSessionExpiredError' })
    assert.equal(env.guard.capture('/auth/admin/login'), null)
  }
})

test('HTTP 401 expires, but wrong credentials, 403, public auth endpoints and anonymous requests never redirect', async () => {
  const http = setup(); const snapshot = http.guard.capture('/admin/bookings')
  assert.equal((await recover(http, snapshot, undefined, false, 401)).kind, 'expired')
  const env = setup({ refreshToken: 'refresh' }); const current = env.guard.capture('/admin/bookings')
  for (const [status, code, url, request] of [[403, 40102, '/admin/bookings', current], [200, 40304, '/admin/bookings', current], [401, 40104, '/auth/admin/login', current], [401, 40105, '/auth/refresh', current], [500, 50001, '/admin/bookings', current], [401, 40102, '/admin/bookings', null]]) {
    assert.equal((await recover(env, request, code, false, status, url)).kind, 'unhandled')
  }
  assert.equal(env.events.refresh, 0)
  assert.equal(env.events.expired, 0)
  assert.equal(env.values.get(`${prefix}_token`), 'old-token')
  assert.equal(context.publicEndpoint('https://example.test/api/v1/auth/admin/login?next=1'), true)
  assert.equal(context.publicEndpoint('/admin/auth/accounts'), false)
})

test('concurrent failed or timed-out renewals share one refresh and one login navigation', async () => {
  for (const refresh of [async () => null, async () => { throw new Error('timeout') }]) {
    const env = setup({ refreshToken: 'refresh', refresh }); const snapshot = env.guard.capture('/admin/bookings')
    const results = await Promise.all(Array.from({ length: 8 }, () => recover(env, snapshot)))
    assert.equal(env.events.refresh, 1)
    assert.equal(env.events.expired, 1)
    assert.equal(env.events.redirects.length, 1)
    assert.ok(results.every(result => ['expired', 'stale'].includes(result.kind)))
  }
})

test('successful renewal preserves the session, rotates credentials and replays late failures without another refresh', async () => {
  const env = setup({ refreshToken: 'refresh', refresh: async () => ({ accessToken: 'new-token', refreshToken: 'new-refresh' }) })
  const snapshot = env.guard.capture('/admin/bookings')
  const results = await Promise.all(Array.from({ length: 6 }, () => recover(env, snapshot)))
  assert.equal(env.events.refresh, 1)
  assert.equal(env.events.refreshed, 1)
  assert.equal(env.events.expired, 0)
  assert.ok(results.every(result => result.kind === 'retry' && result.token === 'new-token'))
  assert.equal(env.values.get(`${prefix}_refresh_token`), 'new-refresh')
  assert.equal(env.values.get(`${prefix}_session_id`), 'session-a')
  assert.equal(env.guard.isStale(snapshot), false)
  assert.equal((await recover(env, snapshot)).kind, 'retry')
  assert.equal(env.events.refresh, 1)
  const retried = env.guard.capture('/admin/bookings')
  assert.equal((await recover(env, retried, 40103, true)).kind, 'expired')
  assert.equal(env.events.refresh, 1)
})

test('old responses cannot clear a new login even when the JWT string is the same', async () => {
  const env = setup({ refreshToken: 'refresh' }); const snapshot = env.guard.capture('/admin/bookings')
  env.values.set(`${prefix}_session_id`, 'session-b')
  assert.equal(env.guard.isStale(snapshot), true)
  assert.equal((await recover(env, snapshot)).kind, 'stale')
  assert.equal(env.events.expired, 0)
  assert.equal(env.events.refresh, 0)
  assert.equal(env.values.get(`${prefix}_token`), 'old-token')
})

test('an in-flight refresh cannot resurrect logout or overwrite a newer account', async () => {
  for (const newLogin of [false, true]) {
    let complete
    const env = setup({ refreshToken: 'refresh', refresh: () => new Promise(resolve => { complete = resolve }) })
    const snapshot = env.guard.capture('/admin/bookings'); const result = recover(env, snapshot)
    env.values.delete(`${prefix}_token`)
    env.values.delete(`${prefix}_session_id`)
    if (newLogin) { env.values.set(`${prefix}_token`, 'new-account-token'); env.values.set(`${prefix}_session_id`, 'session-b') }
    complete({ accessToken: 'stale-renewal' })
    assert.equal((await result).kind, 'stale')
    assert.equal(env.values.get(`${prefix}_token`), newLogin ? 'new-account-token' : undefined)
    assert.equal(env.events.expired, 0)
    assert.equal(env.events.refreshed, 0)
  }
})

test('already-open login page clears an invalid session without a navigation loop', async () => {
  const env = setup({ pathname: '/temple/login' }); const snapshot = env.guard.capture('/admin/bookings')
  assert.equal((await recover(env, snapshot)).kind, 'expired')
  assert.equal(env.events.redirects.length, 0)
  assert.equal(env.events.expired, 1)
})
