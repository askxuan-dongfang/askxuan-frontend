/** Shared administration-session invalidation. No HTTP or framework dependency. */
export const ADMIN_SESSION_EXPIRED_EVENT = 'askxuan:admin-session-expired'
export const ADMIN_SESSION_REFRESHED_EVENT = 'askxuan:admin-session-refreshed'
const sessionCodes = new Set([40101, 40102, 40103])

export class AdminSessionExpiredError extends Error {
  constructor() {
    super('登录已失效，正在前往登录页')
    this.name = 'AdminSessionExpiredError'
  }
}
export function isAdminSessionExpired(error: unknown): error is AdminSessionExpiredError {
  return error instanceof AdminSessionExpiredError
}
export function isSessionFailure(status: unknown, code: unknown): boolean {
  // Permissions and incorrect credentials must never sign out a valid session.
  if (Number(status) === 403 || (Number(code) >= 40300 && Number(code) < 40400) || Number(code) === 40104) return false
  return Number(status) === 401 || sessionCodes.has(Number(code))
}
export function isAuthenticationEndpoint(url: string | undefined): boolean {
  const path = (url || '').split(/[?#]/, 1)[0].replace(/^https?:\/\/[^/]+/i, '').replace(/^\/api\/v1/, '').replace(/\/$/, '')
  return path === '/auth/admin/login' || path === '/auth/refresh'
}

export type AdminRequestSession = { token: string; generation: string }
type RefreshResult = { accessToken: string; refreshToken?: string } | null
type Recovery = { kind: 'unhandled' | 'expired' | 'stale' } | { kind: 'retry'; token: string }
type SessionOptions = {
  prefix: string
  baseUrl: string
  storage: Pick<Storage, 'getItem' | 'removeItem' | 'setItem'>
  location: Pick<Location, 'pathname' | 'search' | 'hash' | 'replace'>
  invalidate: () => void
  refreshed: () => void
  refresh: (refreshToken: string) => Promise<RefreshResult>
  extraKeys?: string[]
}

export function createAdminSessionGuard(options: SessionOptions) {
  let redirecting = false
  let refreshFlight: { token: string; generation: string; promise: Promise<Recovery> } | undefined
  const replacements = new Map<string, string>()
  const read = (suffix: string) => {
    try { return options.storage.getItem(`${options.prefix}_${suffix}`) || '' }
    catch { return '' }
  }
  const matches = (request: AdminRequestSession) => request.generation === read('session_id') && request.token === read('token')
  const wasRefreshed = (request: AdminRequestSession) => request.generation === read('session_id') && replacements.get(`${request.generation}:${request.token}`) === read('token')
  const isStale = (request: AdminRequestSession | null | undefined) => Boolean(request && !matches(request) && !wasRefreshed(request))
  const capture = (url: string | undefined): AdminRequestSession | null => {
    if (isAuthenticationEndpoint(url)) return null
    const token = read('token')
    if (redirecting && !token) throw new AdminSessionExpiredError()
    if (!token) return null
    redirecting = false
    return { token, generation: read('session_id') }
  }
  const expire = (request: AdminRequestSession): Recovery => {
    if (!matches(request)) return { kind: 'stale' }
    if (redirecting) return { kind: 'expired' }
    redirecting = true
    const keys = ['token', 'refresh_token', 'user', 'temple_id', 'temple_name', 'session_id'].map(suffix => `${options.prefix}_${suffix}`)
    for (const key of [...keys, ...(options.extraKeys || [])]) {
      try { options.storage.removeItem(key) } catch { /* Memory state and navigation still invalidate this session. */ }
    }
    options.invalidate()
    const base = '/' + options.baseUrl.split('/').filter(Boolean).join('/')
    const basePath = base === '/' ? '' : base
    const loginPath = `${basePath}/login`
    if (options.location.pathname.replace(/\/$/, '') !== loginPath) {
      const path = options.location.pathname.startsWith(`${basePath}/`) ? options.location.pathname.slice(basePath.length) : '/'
      options.location.replace(`${loginPath}?redirect=${encodeURIComponent(path + options.location.search + options.location.hash)}`)
    }
    return { kind: 'expired' }
  }
  const recover = async (request: AdminRequestSession | null | undefined, url: string | undefined, status: unknown, code: unknown, retried: boolean): Promise<Recovery> => {
    if (!request || isAuthenticationEndpoint(url) || !isSessionFailure(status, code)) return { kind: 'unhandled' }
    if (isStale(request)) return { kind: 'stale' }
    if (wasRefreshed(request)) return retried ? { kind: 'stale' } : { kind: 'retry', token: read('token') }
    if (retried) return expire(request)
    const refreshToken = read('refresh_token')
    if (!refreshToken) return expire(request)
    if (!refreshFlight || refreshFlight.token !== request.token || refreshFlight.generation !== request.generation) {
      const promise = (async (): Promise<Recovery> => {
        let result: RefreshResult = null
        try { result = await options.refresh(refreshToken) } catch { /* A failed/timeout refresh exits through the same path. */ }
        // Never overwrite a later sign-in or restore a session after explicit logout.
        if (!matches(request)) return { kind: 'stale' }
        if (!result?.accessToken) return expire(request)
        try {
          if (result.refreshToken) options.storage.setItem(`${options.prefix}_refresh_token`, result.refreshToken)
          options.storage.setItem(`${options.prefix}_token`, result.accessToken)
        } catch { return expire(request) }
        replacements.set(`${request.generation}:${request.token}`, result.accessToken)
        options.refreshed()
        return { kind: 'retry', token: result.accessToken }
      })()
      refreshFlight = { token: request.token, generation: request.generation, promise }
    }
    return refreshFlight.promise
  }
  return { capture, isStale, recover }
}

/** A login gets a new generation even if its JWT happens to match an earlier one. */
export function startAdminSession(prefix: string): void {
  const generation = typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `${Date.now()}-${Math.random().toString(36).slice(2)}`
  localStorage.setItem(`${prefix}_session_id`, generation)
}
export function subscribeAdminSession(prefix: string, expired: () => void, refreshed: () => void): void {
  for (const [name, listener] of [[ADMIN_SESSION_EXPIRED_EVENT, expired], [ADMIN_SESSION_REFRESHED_EVENT, refreshed]] as const) {
    window.addEventListener(name, event => {
      if ((event as CustomEvent<{ prefix: string }>).detail?.prefix === prefix) listener()
    })
  }
}
