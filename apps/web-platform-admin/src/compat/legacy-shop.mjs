/** Self-contained browser entry: also serialized into the legacy HTML at build time. */
export function runLegacyShop(scope, adminBase = '/admin/') {
  const origin = scope.location.origin
  const base = new URL(adminBase, origin)
  const fallback = '/commerce/dashboard'

  function route(value) {
    // Router destinations must be local paths; do not forward protocol-relative or escaped URLs.
    if (!value.startsWith('/') || value.startsWith('//') || /[\\\u0000-\u001f\u007f]/.test(value)) return null
    const url = new URL(value, origin)
    if (url.origin !== origin) return null
    let path = url.pathname.replace(/^\/shop(?:\/|$)/, '/')
    if (base.pathname !== '/' && path.startsWith(base.pathname)) path = '/' + path.slice(base.pathname.length)
    if (path === '/' || !path) path = fallback
    else if (path !== '/login' && path !== '/commerce' && !path.startsWith('/commerce/')) path = '/commerce' + path
    return path + url.search + url.hash
  }

  const target = new URL((route(scope.location.pathname) || fallback).slice(1), base)
  const query = new URLSearchParams(scope.location.search)
  if (query.has('redirect')) {
    const redirect = route(query.get('redirect') || '')
    query.delete('redirect')
    if (redirect) query.set('redirect', redirect)
  }
  target.search = query.toString()
  target.hash = scope.location.hash

  try {
    const storage = scope.localStorage
    const suffixes = ['refresh_token', 'user', 'session_id', 'token']
    const platformToken = storage.getItem('df_platform_admin_token')
    const legacyToken = storage.getItem('df_shop_admin_token')
    if (!platformToken && legacyToken) {
      const previous = suffixes.map(suffix => storage.getItem(`df_platform_admin_${suffix}`))
      try {
        // Write access token last, and remove missing legacy fields rather than reuse stale credentials.
        for (const suffix of suffixes) {
          const value = storage.getItem(`df_shop_admin_${suffix}`)
          if (value) storage.setItem(`df_platform_admin_${suffix}`, value)
          else storage.removeItem(`df_platform_admin_${suffix}`)
        }
      } catch (error) {
        // Retain the old session if storage cannot complete the transfer.
        for (const [index, suffix] of suffixes.entries()) {
          try {
            if (previous[index] === null) storage.removeItem(`df_platform_admin_${suffix}`)
            else storage.setItem(`df_platform_admin_${suffix}`, previous[index])
          } catch { /* A blocked storage area still allows navigation to login. */ }
        }
        throw error
      }
    }
    // An existing unified identity always wins. Remove old credentials after successful transfer only.
    for (const suffix of suffixes) storage.removeItem(`df_shop_admin_${suffix}`)
  } catch { /* Storage unavailable: the unified login remains reachable. */ }

  try {
    const preference = scope.localStorage.getItem('askxuan-theme') || 'system'
    const dark = preference === 'dark' || (preference === 'system' && scope.matchMedia('(prefers-color-scheme: dark)').matches)
    scope.document.documentElement.dataset.theme = dark ? 'dark' : 'light'
  } catch { /* The HTML's system appearance is a safe fallback. */ }
  scope.location.replace(target.href)
  return target.href
}

/** One HTML file, no Vue runtime, fonts, chunk files or independently versioned app. */
export function legacyShopDocument(adminBase = '/admin/') {
  if (!/^\/(?:[a-zA-Z0-9_-]+\/)*$/.test(adminBase)) throw new Error('Legacy shop requires a same-origin, root-relative admin base ending in /')
  return `<!doctype html>
<html lang="zh-CN"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="robots" content="noindex"><title>问玄东方 · 统一运营管理台</title>
<style>:root{color-scheme:light dark;background:#F6F3EC;color:#253E36;font:16px/1.6 system-ui,sans-serif}body{margin:10vh auto;padding:24px;max-width:32rem}a{color:inherit}@media(prefers-color-scheme:dark){:root:not([data-theme=light]){background:#1C1210;color:#F0E6DA}}:root[data-theme=dark]{background:#1C1210;color:#F0E6DA}</style>
</head><body><p role="status">正在进入统一运营管理台…</p><a href="${adminBase}">进入管理台</a><noscript><p>请启用 JavaScript 以恢复原商城页面和会话，或使用以上入口登录。</p></noscript>
<script>(${runLegacyShop.toString()})(window,${JSON.stringify(adminBase)});</script></body></html>`
}
