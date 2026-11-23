import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import test from 'node:test'

const require = createRequire(new URL('../../apps/web-platform-admin/package.json', import.meta.url))
const ts = require('typescript')
const vue = require('vue')
const read = file => readFileSync(new URL(file, import.meta.url), 'utf8')

function compile(source, props) {
  const js = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS } }).outputText
  const exports = {}
  new Function('exports', 'require', 'defineProps', js)(exports, module => module === 'vue' ? vue : {}, () => props)
  return exports
}

const { createCatalogTranslationApi } = compile(read('./catalog-translations.ts'))
const editor = read('./components/CatalogTranslationButton.vue').match(/<script setup lang="ts">([\s\S]*?)<\/script>/)[1]
const review = {
  revision: '7',
  status: 'review',
  source: { title: '祈福', description: '供灯祈福' },
  fields: { title: 'Blessing' },
  reviewRequired: true,
}

test('background translation requests use canonical IDs, send no source body and report failure independently', async () => {
  const calls = []
  const errors = []
  const problem = new Error('unavailable')
  const api = createCatalogTranslationApi({
    post: async (...args) => { calls.push(args); throw problem }
  }, error => errors.push(error))
  assert.equal(api.queueAfterSave('reward-prize', 48), undefined)
  assert.equal(api.queueAfterSave('belief', 'cat/branch'), undefined)
  await Promise.resolve()
  assert.deepEqual(calls, [
    ['/ai/admin/catalog-translations/reward-prize/48', undefined, { suppressErrorMessage: true }],
    ['/ai/admin/catalog-translations/belief/cat%2Fbranch', undefined, { suppressErrorMessage: true }],
  ])
  assert.deepEqual(errors, [problem, problem])
})

test('partial drafts can be saved and approval keeps the loaded revision and reviewed fields', async () => {
  const calls = []
  const api = createCatalogTranslationApi({
    get: async () => review,
    put: async (_url, body) => {
      calls.push(body)
      return { ...review, fields: body.fields, status: body.publish ? 'published' : 'review' }
    },
  }, assert.fail)
  const state = compile(editor + '\nexport { run, draft, complete, status };', { api, kind: 'temple', recordId: 'T001' })
  await state.run('read')
  assert.equal(state.complete.value, false)
  state.draft.value.title = '  Light a Lamp  '
  await state.run('draft')
  state.draft.value.description = 'Offer a lamp for blessings'
  assert.equal(state.complete.value, true)
  await state.run('publish')
  assert.deepEqual(calls, [
    { revision: '7', fields: { title: 'Light a Lamp' }, publish: false },
    { revision: '7', fields: { title: 'Light a Lamp', description: 'Offer a lamp for blessings' }, publish: true },
  ])
  assert.equal(state.status.value, 'published')
})

test('a stale revision blocks editing until the operator reloads the canonical source', async () => {
  let snapshot = review
  const api = {
    read: async () => snapshot,
    save: async () => { throw Object.assign(new Error('stale'), { apiCode: 40932 }) }
  }
  const state = compile(editor + '\nexport { run, draft, canEdit, error, translation };', { api, kind: 'temple', recordId: 'T001' })
  await state.run('read')
  state.draft.value.title = 'Light a Lamp'
  await state.run('draft')
  assert.equal(state.draft.value.title, 'Light a Lamp')
  assert.equal(state.canEdit.value, false)
  assert.match(state.error.value, /中文内容或英文稿已更新/)
  snapshot = { ...review, revision: '8', source: { title: '新内容' }, fields: {}, status: 'missing' }
  await state.run('read')
  assert.equal(state.translation.value.revision, '8')
  assert.deepEqual(state.draft.value, {})
  assert.equal(state.canEdit.value, true)
})
