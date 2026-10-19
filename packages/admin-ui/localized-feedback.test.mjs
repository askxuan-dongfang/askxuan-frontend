import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createRequire } from 'node:module'
import vm from 'node:vm'
const require = createRequire(new URL('../../apps/web-platform-admin/package.json', import.meta.url))
const ts = require('typescript')
const source = ts.transpileModule(readFileSync(new URL('./localized-feedback.ts', import.meta.url), 'utf8'), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 } }).outputText
const exports = {}
const dictionary = { '确定': '確定', '取消': '取消', '语言': '語言', '输入': '輸入', '错误': '錯誤' }
vm.runInNewContext(source, { exports, require: () => ({ t: value => typeof value === 'string' ? dictionary[value] ?? value : value }) })
test('dialogs localize default buttons, titles and validation without changing entered data', () => {
  let received
  const service = Object.assign(() => {}, { prompt: (...args) => { received = args; return { value: '用户原文' } } })
  const dialog = exports.localizedMessageBox(service)
  const input = { inputPlaceholder: '输入', inputValidator: value => value === '用户原文' || '错误' }
  assert.equal(dialog.prompt('语言', '语言', input).value, '用户原文')
  assert.equal(received[0], '語言'); assert.equal(received[1], '語言')
  assert.equal(received[2].confirmButtonText, '確定'); assert.equal(received[2].inputPlaceholder, '輸入')
  assert.equal(received[2].inputValidator('用户原文'), true); assert.equal(received[2].inputValidator(''), '錯誤')
  assert.equal(input.inputPlaceholder, '输入')
  dialog.prompt('语言', { confirmButtonText: '输入', inputValue: '用户原文' })
  assert.equal(received[1].confirmButtonText, '輸入'); assert.equal(received[1].inputValue, '用户原文')
})
test('notification methods preserve handles, VNodes, and lifecycle callbacks', () => {
  let received
  const handle = { close() {} }, callback = () => {}, vnode = { type: 'div' }
  const service = Object.assign(value => { received = value; return handle }, { success: value => { received = value; return handle }, closeAll: callback })
  const message = exports.localizedMessage(service)
  assert.equal(message.success('语言'), handle); assert.equal(received, '語言')
  message({ message: '语言', onClose: callback }); assert.equal(received.message, '語言'); assert.equal(received.onClose, callback)
  message(vnode); assert.equal(received, vnode); assert.equal(message.closeAll, callback)
})
