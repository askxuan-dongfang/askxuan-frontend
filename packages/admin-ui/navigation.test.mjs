import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createRequire, stripTypeScriptTypes } from 'node:module'
import test from 'node:test'

// Exercise the real Vue watchers/lifecycle without launching a second browser backend.
const require = createRequire(new URL('../../apps/web-platform-admin/package.json', import.meta.url))
const { createRenderer, markRaw, nextTick, onBeforeUnmount, onMounted, ref, watch } = require('vue')
const source = stripTypeScriptTypes(await readFile(new URL('./navigation.ts', import.meta.url), 'utf8'))
  .replace(/^import .+ from 'vue'\s*/m, '').replace('export function', 'function')
const useNavigation = new Function('nextTick', 'onBeforeUnmount', 'onMounted', 'ref', 'watch', `${source}\nreturn useAdminNavigation;`)(nextTick, onBeforeUnmount, onMounted, ref, watch)
const renderer = createRenderer({
  createComment: () => ({}), createText: () => ({}), createElement: () => ({}),
  insert() {}, remove() {}, setText() {}, setElementText() {}, patchProp() {},
  parentNode: () => null, nextSibling: () => null
})
async function flush() { await nextTick(); await nextTick() }

function fixture({ mobile = true, overflow = '' } = {}) {
  const handlers = new Map()
  const mediaHandlers = new Map()
  const media = { matches: mobile, addEventListener: (name, fn) => mediaHandlers.set(name, fn), removeEventListener: name => mediaHandlers.delete(name) }
  const document = { documentElement: { style: { overflow } }, activeElement: null, addEventListener: (name, fn) => handlers.set(name, fn), removeEventListener: name => handlers.delete(name) }
  globalThis.document = document
  globalThis.window = { matchMedia: () => media }
  const element = name => markRaw({ name, closest: () => null, getClientRects: () => [{}], focus() { document.activeElement = this } })
  const first = element('close')
  const active = element('selected menu')
  const last = element('last menu')
  const trigger = element('trigger')
  const items = [first, active, last]
  const sidebar = element('sidebar')
  sidebar.contains = value => items.includes(value) || value === sidebar
  sidebar.querySelectorAll = () => items
  sidebar.querySelector = () => active
  const route = ref('/dashboard')
  let api
  const app = renderer.createApp({ setup() { api = useNavigation(() => route.value); api.sidebarRef.value = sidebar; api.toggleRef.value = trigger; return () => null } })
  app.mount({})
  function key(key, shiftKey = false) {
    const event = { key, shiftKey, prevented: false, preventDefault() { this.prevented = true } }
    handlers.get('keydown')?.(event)
    return event
  }
  return { api, document, route, items, sidebar, trigger, handlers, mediaHandlers, key,
    resize(matches) { media.matches = matches; mediaHandlers.get('change')?.({ matches }) },
    close() { app.unmount(); delete globalThis.document; delete globalThis.window }
  }
}

test('mobile drawer focuses the selected page, locks scroll, and Escape restores trigger focus and prior scrolling', async () => {
  const f = fixture({ overflow: 'clip' })
  try {
    f.api.toggleNavigation(); await flush()
    assert.equal(f.document.activeElement, f.items[1])
    assert.equal(f.document.documentElement.style.overflow, 'hidden')
    assert.equal(f.key('Escape').prevented, true)
    await flush()
    assert.equal(f.api.drawerOpen.value, false)
    assert.equal(f.document.documentElement.style.overflow, 'clip')
    assert.equal(f.document.activeElement, f.trigger)
  } finally { f.close() }
})

test('Tab and Shift+Tab stay inside the mobile navigation, while an unrelated dialog keeps its keyboard events', async () => {
  const f = fixture()
  try {
    f.api.toggleNavigation(); await flush()
    f.items[2].focus(); assert.equal(f.key('Tab').prevented, true); assert.equal(f.document.activeElement, f.items[0])
    f.items[0].focus(); assert.equal(f.key('Tab', true).prevented, true); assert.equal(f.document.activeElement, f.items[2])
    f.document.activeElement = { name: 'teleported dialog' }
    assert.equal(f.key('Escape').prevented, false)
    assert.equal(f.api.drawerOpen.value, true)
  } finally { f.close() }
})

test('route changes and desktop resizing close the navigation and release its scroll lock', async () => {
  const f = fixture()
  try {
    f.api.toggleNavigation(); await flush(); f.route.value = '/bookings'; await flush()
    assert.equal(f.api.drawerOpen.value, false)
    assert.equal(f.document.documentElement.style.overflow, '')
    f.api.toggleNavigation(); await flush(); f.resize(false); await flush()
    assert.equal(f.api.drawerOpen.value, false)
    assert.equal(f.api.mobile.value, false)
    assert.equal(f.document.documentElement.style.overflow, '')
    f.api.toggleNavigation(); await flush()
    assert.equal(f.api.collapsed.value, true)
    assert.equal(f.api.drawerOpen.value, false)
  } finally { f.close() }
})

test('unmount removes handlers and restores scrolling without late focus', async () => {
  const f = fixture({ overflow: 'auto' })
  f.api.toggleNavigation(); await flush()
  const focusBefore = f.document.activeElement
  f.close(); await flush()
  assert.equal(f.document.documentElement.style.overflow, 'auto')
  assert.equal(f.document.activeElement, focusBefore)
  assert.equal(f.handlers.size, 0)
  assert.equal(f.mediaHandlers.size, 0)
})


test('rapid close and reopen keeps focus inside the current drawer', async () => {
  const f = fixture()
  try {
    f.api.toggleNavigation(); await flush()
    f.api.closeNavigation(); await nextTick()
    f.api.toggleNavigation(); await flush()
    assert.equal(f.api.drawerOpen.value, true)
    assert.equal(f.document.activeElement, f.items[1])
    assert.equal(f.document.documentElement.style.overflow, 'hidden')
  } finally { f.close() }
})
