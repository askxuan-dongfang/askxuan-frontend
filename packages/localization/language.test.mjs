import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import vm from 'node:vm'
const require = createRequire(new URL('../../apps/web-platform-admin/package.json', import.meta.url))
const ts = require('typescript')
const source = ts.transpileModule(readFileSync(new URL('./language.ts', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
const catalog = JSON.parse(readFileSync(new URL('./zh-Hant.json', import.meta.url), 'utf8'))
function runtime({ preference, languages = ['zh-CN'], blocked = false } = {}) {
  const listeners = new Map(), values = new Map(preference ? [['askxuan-language', preference]] : [])
  const exports = {}, document = { documentElement: { lang: '', dataset: {} } }, navigator = { languages, language: languages[0] }
  const window = { addEventListener: (name, fn) => { if (!listeners.has(name)) listeners.set(name, []); listeners.get(name).push(fn) }, dispatchEvent: event => { for (const fn of listeners.get(event.type) || []) fn(event) } }
  const localStorage = { getItem: key => { if (blocked) throw Error('blocked'); return values.get(key) ?? null }, setItem: (key, value) => { if (blocked) throw Error('blocked'); values.set(key, value) } }
  vm.runInNewContext(source, { exports, require: () => ({ default: catalog }), document, navigator, window, localStorage, CustomEvent: class { constructor(type, data) { this.type = type; Object.assign(this, data) } } })
  return { api: exports, document, navigator, values, dispatch: event => window.dispatchEvent(event) }
}
test('system resolves scripts before region and uses the first supported preferred language', () => {
 const { api } = runtime()
 for (const [list, expected] of [[['zh-CN'],'zh-Hans'],[['zh-SG'],'zh-Hans'],[['zh-TW'],'zh-Hant'],[['zh-HK'],'zh-Hant'],[['zh-MO'],'zh-Hant'],[['zh-Hans-HK'],'zh-Hans'],[['zh_Hant_CN'],'zh-Hant'],[['en-US','zh-TW'],'zh-Hant'],[['en-US'],'zh-Hans'],[[],'zh-Hans']]) assert.equal(api.resolveLanguage('system', list), expected)
 assert.equal(api.resolveLanguage('zh-Hant', ['zh-CN']), 'zh-Hant')
})
test('invalid saved preference falls back, persists selection and updates document semantics', () => {
 const { api, document, values } = runtime({ preference: 'en', languages: ['zh-TW'] })
 assert.equal(api.getLanguagePreference(), 'system'); assert.equal(api.getLanguage(), 'zh-Hant')
 api.setLanguagePreference('zh-Hans'); assert.equal(values.get('askxuan-language'), 'zh-Hans'); assert.equal(document.documentElement.lang, 'zh-Hans')
 api.setLanguagePreference('en'); assert.equal(api.getLanguagePreference(), 'zh-Hans')
})
test('system changes only affect system mode; storage events synchronize tabs and clearing resets', () => {
 const { api, navigator, dispatch, values } = runtime(); let updates = 0
 const unsubscribe = api.subscribeLanguage(() => updates++)
 navigator.languages = ['zh-Hant']; dispatch({type:'languagechange'}); assert.equal(api.getLanguage(), 'zh-Hant')
 api.setLanguagePreference('zh-Hans'); dispatch({type:'languagechange'}); assert.equal(api.getLanguage(), 'zh-Hans')
 values.set('askxuan-language','zh-Hant'); dispatch({type:'storage',key:'askxuan-language'}); assert.equal(api.getLanguagePreference(),'zh-Hant')
 values.clear(); dispatch({type:'storage',key:null}); assert.equal(api.getLanguagePreference(),'system')
 unsubscribe(); const previous = updates; api.setLanguagePreference('zh-Hans'); assert.equal(updates, previous)
})
test('blocked storage remains usable; unknown data and interpolation values remain verbatim', () => {
 const { api } = runtime({ blocked: true }); api.setLanguagePreference('zh-Hant')
 assert.equal(api.getLanguage(), 'zh-Hant'); assert.equal(api.t('语言'), '語言')
 assert.equal(api.t('用户自由输入：头发与发财 19382'), '用户自由输入：头发与发财 19382')
 const object = { content:'语言' }; assert.equal(api.t(object),object)
 assert.equal(api.message(['语言', ''], '用户原文'), '語言用户原文')
 api.setLanguagePreference('zh-Hans'); assert.equal(api.t('语言'),'语言')
})
