import './styles/index.css'
import { initAdminTheme } from '../../../packages/admin-ui/theme'
import { legacyShopTarget } from './router'

initAdminTheme()

const unifiedBase = import.meta.env.DEV ? new URL(import.meta.env.VITE_UNIFIED_ADMIN_URL || 'http://localhost:5210/') : new URL('/admin/', window.location.origin)
const target = new URL(legacyShopTarget(window.location.pathname).slice(1), unifiedBase)
const query = new URLSearchParams(window.location.search)
const redirect = query.get('redirect')
if (redirect?.startsWith('/') && !redirect.startsWith('//')) query.set('redirect', legacyShopTarget(redirect))
target.search = query.toString()
target.hash = window.location.hash
// A pre-existing unified session takes precedence; never silently switch administrators.
try {
  if (!localStorage.getItem('df_platform_admin_token') && localStorage.getItem('df_shop_admin_token')) {
    for (const suffix of ['token', 'refresh_token', 'user']) {
      const value = localStorage.getItem(`df_shop_admin_${suffix}`)
      if (value) localStorage.setItem(`df_platform_admin_${suffix}`, value)
    }
  }
  for (const suffix of ['token', 'refresh_token', 'user']) localStorage.removeItem(`df_shop_admin_${suffix}`)
} catch { /* Storage disabled: the unified login remains available. */ }
window.location.replace(target.href)
