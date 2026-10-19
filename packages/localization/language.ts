import messages from './zh-Hant.json'

export type LanguagePreference = 'system' | 'zh-Hans' | 'zh-Hant'
export type AppLanguage = Exclude<LanguagePreference, 'system'>
export const LANGUAGE_STORAGE_KEY = 'askxuan-language'
export const LANGUAGE_EVENT = 'askxuan:language-change'
export const languageChoices = [
  { value: 'system', label: '跟随系统' },
  { value: 'zh-Hans', label: '简体中文' },
  { value: 'zh-Hant', label: '繁體中文' },
] as const

export function isLanguagePreference(value: unknown): value is LanguagePreference {
  return value === 'system' || value === 'zh-Hans' || value === 'zh-Hant'
}

/** Respect explicit script before region; choose the first supported preferred language. */
export function resolveLanguage(preference: LanguagePreference, languages: readonly string[]): AppLanguage {
  if (preference !== 'system') return preference
  const parts = (languages.find(value => /^zh(?:[-_]|$)/i.test(value)) || '').replace(/_/g, '-').toLowerCase().split('-')
  if (parts[0] !== 'zh') return 'zh-Hans'
  if (parts.includes('hant')) return 'zh-Hant'
  if (parts.includes('hans')) return 'zh-Hans'
  return parts.some(part => ['tw', 'hk', 'mo'].includes(part)) ? 'zh-Hant' : 'zh-Hans'
}

export function readLanguagePreference(): LanguagePreference {
  try {
    const value = localStorage.getItem(LANGUAGE_STORAGE_KEY)
    return isLanguagePreference(value) ? value : 'system'
  } catch { return 'system' }
}

let preference: LanguagePreference = 'system'
let language: AppLanguage = 'zh-Hans'
let initialized = false
const subscribers = new Set<() => void>()
const dictionary: Record<string, string> = messages

function publish() {
  language = resolveLanguage(preference, navigator.languages?.length ? navigator.languages : [navigator.language])
  document.documentElement.lang = language
  document.documentElement.dataset.languagePreference = preference
  subscribers.forEach(listener => listener())
  window.dispatchEvent(new CustomEvent(LANGUAGE_EVENT, { detail: { preference, language } }))
}

export function initLanguage() {
  if (initialized || typeof window === 'undefined') return
  initialized = true
  preference = readLanguagePreference()
  window.addEventListener('languagechange', () => { if (preference === 'system') publish() })
  window.addEventListener('storage', event => {
    if (event.key !== LANGUAGE_STORAGE_KEY && event.key !== null) return
    preference = readLanguagePreference()
    publish()
  })
  publish()
}

export function getLanguagePreference() { initLanguage(); return preference }
export function getLanguage() { initLanguage(); return language }
export function languageSnapshot() { return `${getLanguagePreference()}:${getLanguage()}` }
export function setLanguagePreference(value: LanguagePreference) {
  if (!isLanguagePreference(value)) return
  initLanguage()
  preference = value
  try { localStorage.setItem(LANGUAGE_STORAGE_KEY, value) } catch { /* Session-only when storage is blocked. */ }
  publish()
}
export function subscribeLanguage(listener: () => void) {
  initLanguage()
  subscribers.add(listener)
  return () => { subscribers.delete(listener) }
}

/** Catalog lookup only: never transliterate arbitrary input or change business values. */
export function translate<T>(value: T, locale: AppLanguage): T {
  if (locale !== 'zh-Hant' || typeof value !== 'string') return value
  if (Object.prototype.hasOwnProperty.call(dictionary, value)) return dictionary[value] as T
  const trimmed = value.trim()
  if (trimmed && Object.prototype.hasOwnProperty.call(dictionary, trimmed)) {
    return value.replace(trimmed, dictionary[trimmed]) as T
  }
  return value
}
export function t<T>(value: T): T { return translate(value, getLanguage()) }

/** Interpolations are kept verbatim; only cataloged template segments are translated. */
export function message(parts: TemplateStringsArray, ...values: unknown[]) {
  return parts.reduce((result, part, index) => result + t(part) + (index < values.length ? String(values[index]) : ''), '')
}
