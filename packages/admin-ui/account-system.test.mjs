import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import test from 'node:test'
const require = createRequire(new URL('../../apps/web-platform-admin/package.json', import.meta.url))
const ts = require('typescript'), vue = require('vue')
const read = path => readFileSync(new URL(path, import.meta.url), 'utf8')
function compile(source, bindings = {}) {
  const output = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  const exports = {}
  new Function('exports', 'require', output)(exports, name => bindings[name] ?? {})
  return exports
}
const identity = compile(read('../../apps/web-platform-admin/src/utils/accountIdentity.ts'))
const templeState = compile(read('../../apps/web-platform-admin/src/utils/templeState.ts'))

test('verified, legacy, pending and unavailable credentials give distinct recovery guidance', () => {
  const old = { credentialState: 'legacy_password', email: '', emailVerified: false, canResetPassword: false }
  assert.equal(identity.credentialLabel(old), '原有密码账号')
  assert.match(identity.recoveryLabel(old), /不能通过邮箱找回/)
  assert.equal(identity.credentialLabel({ ...old, credentialState: 'verified_email', emailVerified: true }), '已验证邮箱')
  assert.match(identity.recoveryLabel({ ...old, emailVerified: true, canResetPassword: true }), /本人可在登录页/)
  assert.equal(identity.credentialLabel({ ...old, activationStatus: 'pending' }), '待本人激活')
  assert.match(identity.recoveryLabel({ ...old, activationStatus: 'pending' }), /验证邀请邮箱/)
  assert.equal(identity.credentialLabel({ ...old, credentialState: 'unavailable' }), '认证资料待核对')
})

test('business identity links preserve domain boundaries and do not create a consumer association', () => {
  assert.equal(identity.bindingRoute({ type: 'master', id: 'W003' }), '/master/detail/W003')
  assert.equal(identity.bindingRoute({ type: 'temple', id: 'T001' }), '/temple/detail/T001')
  assert.equal(identity.bindingRoute({ type: 'shop', id: '9' }), null)
})

test('temple publication requires certification and normal platform state, never a recommendation flag', () => {
  const current = { stateVersion: 0, authStatus: 'certified', platformStatus: 'normal', shelfStatus: 'off_shelf' }
  assert.equal(templeState.templeStateAvailable(current), true)
  assert.equal(templeState.canShelfTemple(current), true)
  for (const change of [{ authStatus: 'legacy_unknown' }, { authStatus: 'pending' }, { platformStatus: 'banned', recommended: true }]) assert.equal(templeState.canShelfTemple({ ...current, ...change }), false)
  assert.equal(templeState.templeStateAvailable({ ...current, stateVersion: undefined }), false)
  assert.equal(templeState.templeAuthLabel('legacy_unknown'), '历史认证待核对')
})

test('late account detail responses cannot replace another account and failed reload hides stale data', async () => {
  const script = read('../../apps/web-platform-admin/src/views/settings/SettingsAccountDetailView.vue').match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]
  const route = vue.reactive({ params: { id: '1' } }), reads = []
  const state = compile(script + '\nexport {load,detail,error};', {
    vue: { ...vue, watch() {} }, 'vue-router': { useRoute: () => route },
    '@/api/auth': { getAdminAccountDetail: id => new Promise((resolve, reject) => reads.push({ id, resolve, reject })) },
    '@/api/client': { isAdminSessionExpired: () => false }
  })
  const one = state.load(); route.params.id = '2'; const two = state.load()
  const data = id => ({ account: { id, name: 'name' }, identity: {}, bindings: [], blockedReasons: [] })
  reads[1].resolve(data(2)); await two
  reads[0].resolve(data(1)); await one
  assert.equal(state.detail.value.account.id, 2)
  const retry = state.load(); assert.equal(state.detail.value, null)
  reads[2].reject(new Error('unavailable')); await retry
  assert.equal(state.detail.value, null); assert.equal(state.error.value, 'unavailable')
})
