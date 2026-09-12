import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { stripTypeScriptTypes } from 'node:module'
import test from 'node:test'
import vm from 'node:vm'

const source = await readFile(new URL('./theme.ts', import.meta.url), 'utf8')
function setup({ saved, systemDark = false, unavailable = false } = {}) {
  const values = new Map(saved === undefined ? [] : [['askxuan-theme', saved]])
  const windowEvents = new Map()
  const mediaEvents = new Map()
  const media = { matches: systemDark, addEventListener: (name, fn) => mediaEvents.set(name, fn) }
  const root = { dataset: {}, style: {}, classList: { toggle(name, enabled) { this[name] = enabled } } }
  const window = { matchMedia: () => media, addEventListener: (name, fn) => windowEvents.set(name, fn), dispatchEvent() {} }
  const context = vm.createContext({ window, document: { documentElement: root }, localStorage: {
    getItem(key) { if (unavailable) throw new Error('Storage blocked'); return values.get(key) ?? null },
    setItem(key, value) { if (unavailable) throw new Error('Storage blocked'); values.set(key, value) }
  }, CustomEvent: class { constructor(type, options) { this.type = type; this.detail = options?.detail } } })
  const stripped = stripTypeScriptTypes(source, { mode: 'strip' }).replace(/\bexport /g, '')
  vm.runInContext(stripped + '\nthis.api = { initAdminTheme, getThemePreference, setThemePreference, subscribeThemePreference, resolveTheme, isThemePreference };', context)
  context.api.initAdminTheme()
  return { api: context.api, root, values, system(dark) { media.matches = dark; mediaEvents.get('change')?.() }, storage(key, value) { if (value === null) values.delete(key); else values.set(key, value); windowEvents.get('storage')?.({ key }) } }
}

test('default follows system and explicit choices persist without following subsequent OS changes', () => {
  const env = setup({ systemDark: true })
  assert.equal(env.root.dataset.theme, 'dark')
  assert.equal(env.api.getThemePreference(), 'system')
  env.system(false)
  assert.equal(env.root.dataset.theme, 'light')
  env.api.setThemePreference('dark')
  env.system(false)
  assert.equal(env.root.dataset.theme, 'dark')
  assert.equal(env.values.get('askxuan-theme'), 'dark')
  env.api.setThemePreference('system')
  assert.equal(env.values.get('askxuan-theme'), 'system')
  assert.equal(env.root.dataset.theme, 'light')
})

test('cross-tab changes and cleared preferences update the page and all controls', () => {
  const env = setup({ saved: 'light', systemDark: true })
  const received = []
  const unsubscribe = env.api.subscribeThemePreference(value => received.push(value))
  env.storage('unrelated', 'dark')
  assert.equal(env.root.dataset.theme, 'light')
  env.storage('askxuan-theme', 'dark')
  assert.equal(env.root.dataset.theme, 'dark')
  env.storage('askxuan-theme', null)
  assert.equal(env.api.getThemePreference(), 'system')
  assert.deepEqual(received, ['light', 'dark', 'system'])
  unsubscribe()
  env.api.setThemePreference('light')
  assert.equal(received.length, 3)
})

test('invalid persisted input and blocked storage retain a usable session appearance', () => {
  const invalid = setup({ saved: 'broken', systemDark: true })
  assert.equal(invalid.api.getThemePreference(), 'system')
  assert.equal(invalid.root.style.colorScheme, 'dark')
  const blocked = setup({ unavailable: true })
  blocked.api.setThemePreference('dark')
  assert.equal(blocked.root.dataset.theme, 'dark')
  assert.equal(blocked.root.classList.dark, true)
  blocked.api.setThemePreference('invalid')
  assert.equal(blocked.api.getThemePreference(), 'dark')
})

test('chart theme changes repaint chrome and gradients while preserving data, callbacks and selection state', async () => {
  const tokens = JSON.parse(await readFile(new URL('../design-tokens/tokens.json', import.meta.url), 'utf8'))
  const chartSource = await readFile(new URL('./chart-theme.ts', import.meta.url), 'utf8')
  let palette = tokens.themes.light.color
  const variable = name => ({
    '--admin-primary': palette.brand.default, '--admin-primary-hover': palette.brand.light,
    '--admin-accent': palette.accent.default, '--admin-text': palette.text.primary,
    '--admin-text-secondary': palette.text.secondary, '--admin-surface': palette.bg.secondary,
    '--admin-border': palette.border.default, '--admin-success': palette.state.success,
    '--admin-warning': palette.state.warning, '--admin-danger': palette.state.error, '--admin-info': palette.state.info
  })[name] || ''
  const context = vm.createContext({ tokens, document: { documentElement: {} }, getComputedStyle: () => ({ getPropertyValue: variable }) })
  const stripped = stripTypeScriptTypes(chartSource.replace(/^import tokens[^\n]*\n/, ''), { mode: 'strip' }).replace(/\bexport /g, '')
  vm.runInContext(stripped + '\nthis.repaint = withAdminChartTheme;', context)
  const formatter = value => String(value)
  const initial = { tooltip: { formatter }, legend: { selected: { '#C45A3C': false } }, dataZoom: [{ start: 20, end: 80 }],
    xAxis: { data: ['#C45A3C', '九月'] }, series: [{ name: '#C45A3C', data: [{ name: '#C45A3C', value: 37 }],
      itemStyle: { color: '#C45A3C' }, areaStyle: { color: { type: 'linear', colorStops: [{ offset: 0, color: 'rgba(196,90,60,0.3)' }] } } }] }
  const light = context.repaint(initial)
  assert.equal(light.series[0].itemStyle.color, '#284D43')
  assert.equal(light.series[0].areaStyle.color.colorStops[0].color, 'rgba(40,77,67,0.3)')
  assert.equal(light.tooltip.formatter, formatter)
  assert.equal(JSON.stringify(light.series[0].data), JSON.stringify(initial.series[0].data))
  assert.equal(light.series[0].name, '#C45A3C')
  assert.equal(light.xAxis.data[0], '#C45A3C')
  assert.equal(light.legend.selected['#C45A3C'], false)
  assert.equal(light.dataZoom[0].start, 20)
  assert.equal(initial.series[0].itemStyle.color, '#C45A3C')
  palette = tokens.color
  const dark = context.repaint(light)
  assert.equal(dark.series[0].itemStyle.color, '#C45A3C')
  assert.equal(dark.series[0].areaStyle.color.colorStops[0].color, 'rgba(196,90,60,0.3)')
  assert.equal(dark.textStyle.color, '#F0E6DA')
  assert.equal(dark.legend.selected['#C45A3C'], false)
})
