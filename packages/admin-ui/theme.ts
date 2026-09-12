/** Shared, dependency-free appearance state for all administration entry points. */
export type ThemePreference = 'light' | 'dark' | 'system'
export type ResolvedTheme = 'light' | 'dark'
export const THEME_STORAGE_KEY = 'askxuan-theme'
export const ADMIN_THEME_EVENT = 'askxuan:admin-theme-change'

export function isThemePreference(value: unknown): value is ThemePreference {
  return value === 'light' || value === 'dark' || value === 'system'
}
export function resolveTheme(preference: ThemePreference, systemDark: boolean): ResolvedTheme {
  return preference === 'system' ? systemDark ? 'dark' : 'light' : preference
}
export function readThemePreference(): ThemePreference {
  try { const value = localStorage.getItem(THEME_STORAGE_KEY); return isThemePreference(value) ? value : 'system' }
  catch { return 'system' }
}

let preference: ThemePreference = 'system'
let initialized = false
let systemQuery: MediaQueryList | undefined
const subscribers = new Set<(value: ThemePreference) => void>()

function applyTheme() {
  const theme = resolveTheme(preference, Boolean(systemQuery?.matches))
  const root = document.documentElement
  root.dataset.theme = theme
  root.dataset.themePreference = preference
  root.classList.toggle('dark', theme === 'dark')
  root.style.colorScheme = theme
  subscribers.forEach(listener => listener(preference))
  window.dispatchEvent(new CustomEvent(ADMIN_THEME_EVENT, { detail: { preference, theme } }))
}

export function initAdminTheme() {
  if (initialized || typeof window === 'undefined') return
  initialized = true
  preference = readThemePreference()
  systemQuery = window.matchMedia('(prefers-color-scheme: dark)')
  systemQuery.addEventListener('change', () => { if (preference === 'system') applyTheme() })
  window.addEventListener('storage', event => {
    if (event.key !== THEME_STORAGE_KEY && event.key !== null) return
    preference = readThemePreference()
    applyTheme()
  })
  applyTheme()
}

export function getThemePreference(): ThemePreference {
  initAdminTheme()
  return preference
}
export function setThemePreference(value: ThemePreference) {
  if (!isThemePreference(value)) return
  initAdminTheme()
  preference = value
  try { localStorage.setItem(THEME_STORAGE_KEY, value) } catch { /* The selection still applies to this tab when storage is unavailable. */ }
  applyTheme()
}
export function subscribeThemePreference(listener: (value: ThemePreference) => void) {
  initAdminTheme()
  subscribers.add(listener)
  listener(preference)
  return () => { subscribers.delete(listener) }
}
