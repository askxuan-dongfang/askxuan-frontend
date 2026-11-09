import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import test from 'node:test'
const require = createRequire(new URL('../../package.json', import.meta.url))
const ts = require('typescript'), vue = require('vue')
function stateOf(file, expose, bindings = {}) {
  const source = readFileSync(new URL(file, import.meta.url), 'utf8').match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]
  const js = ts.transpileModule(source + '\nexport {' + expose + '};', { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
  const exports = {}
  new Function('exports', 'require', js)(exports, name => bindings[name] ?? ({
    vue: { ...vue, onMounted() {} },
    'vue-router': { useRoute: () => ({ params: {}, query: {} }), useRouter: () => ({ replace() {}, push() {} }) },
    '@/stores/auth': { useAuthStore: () => ({ templeId: 'T001' }) },
    '@/i18n': { ElMessage: { success() {}, warning() {} } },
    '../../../../packages/localization/language': { t: value => value }
  }[name] ?? {}))
  return exports
}
test('deleting a middle service slot and adding preserves existing unique slot identities', () => {
  const state = stateOf('./ServiceEditView.vue', 'form,addSlot,removeSlot')
  state.addSlot(); state.addSlot(); state.addSlot()
  state.removeSlot(1); state.addSlot()
  assert.deepEqual(state.form.slots.map(slot => slot.code), ['slot_01', 'slot_03', 'slot_04'])
  assert.equal(new Set(state.form.slots.map(slot => slot.code)).size, 3)
})
test('booking task links apply status/page, browser navigation and manual filter changes', async () => {
  const route = vue.reactive({ query: { status: 'pending', page: '2' } })
  const requests = []
  const state = stateOf('./BookingListView.vue', 'query,load,onSearch', {
    'vue-router': { useRoute: () => route, useRouter: () => ({ replace: async value => { route.query = value.query } }) },
    '@/api/booking': { listBookings: async query => { requests.push(query); return { list: [], total: 0 } } }
  })
  await state.load(); assert.equal(requests.at(-1).status, 'pending'); assert.equal(requests.at(-1).page, 2)
  route.query = { status: 'confirmed', page: '3' }; await vue.nextTick()
  assert.equal(requests.at(-1).status, 'confirmed'); assert.equal(requests.at(-1).page, 3)
  route.query = { status: ['pending'], page: '-1', size: 'NaN' }; await vue.nextTick()
  assert.equal(state.query.status, ''); assert.equal(state.query.page, 1); assert.equal(state.query.size, 20)
  const count = requests.length
  state.query.status = 'pending'; state.onSearch(); await vue.nextTick()
  assert.equal(route.query.status, 'pending'); assert.equal(requests.at(-1).page, 1); assert.equal(requests.length, count + 1)
})
test('failed master directory stays failed until the directory retry succeeds', async () => {
  let attempts = 0
  const state = stateOf('./SchedulesView.vue', 'loadMasters,load,mastersReady,masters,error,ready', {
    dayjs: { default: () => ({ format: () => '2026-11-09' }) },
    '@/api/master': { listMasters: async () => { if (++attempts === 1) throw new Error('目录暂时失败'); return { list: [{ id: 'M1' }], total: 1 } } },
    '@/api/client': { default: { get: async () => ({ list: [] }) } }
  })
  await state.loadMasters(); assert.equal(state.error.value, '目录暂时失败'); assert.equal(state.mastersReady.value, false)
  await state.load(); assert.equal(state.error.value, '目录暂时失败')
  await state.loadMasters(); await vue.nextTick()
  assert.equal(attempts, 2); assert.equal(state.mastersReady.value, true); assert.equal(state.masters.value[0].id, 'M1')
  await state.load(); assert.equal(state.ready.value, true); assert.equal(state.error.value, '')
})
for (const [file, api, method, response] of [
  ['MasterListView.vue', '@/api/master', 'listMasters', { list: [], total: 0 }],
  ['ServiceListView.vue', '@/api/service', 'listServices', { list: [] }],
  ['ReviewListView.vue', '@/api/review', 'listReviews', { list: [], total: 0 }],
  ['TempleGalleryView.vue', '@/api/temple', 'getTempleImages', { list: [] }],
  ['BookingDetailView.vue', '@/api/booking', 'getBooking', { id: 'B1', status: 'pending', paymentStatus: 'success' }]
]) test(`${file} keeps an error after failure and clears it only on an explicit successful retry`, async () => {
  let fail = true
  const fn = file === 'TempleGalleryView.vue' ? 'loadData' : 'load'
  const state = stateOf('./' + file, `${fn},loadError,loading`, {
    [api]: { [method]: async () => { if (fail) throw new Error('读取超时'); return response }, getBookingStatusLog: async () => ({ list: [] }) }
  })
  await state[fn](); assert.equal(state.loadError.value, '读取超时'); assert.equal(state.loading.value, false)
  fail = false; await state[fn](); assert.equal(state.loadError.value, ''); assert.equal(state.loading.value, false)
})
