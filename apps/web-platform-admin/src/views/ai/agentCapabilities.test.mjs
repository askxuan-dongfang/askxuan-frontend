import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import ts from 'typescript'
const source = readFileSync(new URL('./agentCapabilities.ts', import.meta.url), 'utf8')
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2020 } }).outputText
const { addCapability, changeCapability, capabilityKind } = await import('data:text/javascript;base64,' + Buffer.from(compiled).toString('base64'))
const skill = { code: 'bazi', name: '八字', description: '真实计算', defaultPrompt: '经审查的完整提示词', sourceStatus: 'enabled', toolServer: 'taibu', toolName: 'bazi', toolAvailable: true, einoSupported: true }
function draft() { return { skills: [{ code: 'general', enabled: true, prompt: '', useTool: false }], evaluation: [{ id: 'general', skillCode: 'general' }] } }
test('individual add preserves reviewed prompt and cannot duplicate or enable a stopped source', () => {
 const d = draft()
 assert.equal(addCapability(d, skill), true)
 assert.equal(d.skills[1].prompt, skill.defaultPrompt)
 assert.equal(d.skills[1].useTool, true)
 assert.equal(addCapability(d, skill), false)
 assert.equal(addCapability(d, { ...skill, code: 'disabled', sourceStatus: 'disabled' }), false)
 assert.equal(d.skills.length, 2)
})
test('confirmed removal cleans only linked cases and leaves source and published snapshot intact', () => {
 const d = draft(); addCapability(d, skill)
 d.evaluation.push({ id: 'bazi', skillCode: 'bazi' })
 const published = structuredClone(d)
 assert.equal(changeCapability(d, 'bazi', 'remove'), true)
 assert.deepEqual(d.evaluation.map(c => c.id), ['general'])
 assert.equal(published.skills.length, 2)
 assert.equal(skill.defaultPrompt, '经审查的完整提示词')
 assert.equal(addCapability(d, skill), true)
})
test('disable retains prompt and tool binding for re-enable; general remains protected', () => {
 const d = draft(); addCapability(d, skill)
 d.evaluation.push({ id: 'bazi', skillCode: 'bazi' })
 assert.equal(changeCapability(d, 'bazi', 'disable'), true)
 assert.equal(d.skills[1].enabled, false)
 assert.equal(d.skills[1].useTool, true)
 assert.equal(changeCapability(d, 'bazi', 'enable'), true)
 assert.equal(d.skills[1].enabled, true)
 for (const action of ['remove', 'disable']) assert.equal(changeCapability(d, 'general', action), false)
 assert.equal(changeCapability(d, 'missing', 'remove'), false)
})
test('tool classification separates MCP, builtin and prompt-only skills', () => {
 assert.equal(capabilityKind(skill), 'mcp')
 assert.equal(capabilityKind({ ...skill, toolServer: 'builtin' }), 'builtin')
 assert.equal(capabilityKind({ ...skill, toolName: '' }), 'skill')
})
