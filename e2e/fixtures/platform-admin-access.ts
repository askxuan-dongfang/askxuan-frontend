import type { Page, Route } from '@playwright/test'
import type { AdminAccess } from '../../apps/web-platform-admin/src/api/auth'

// Browser fixtures model the public auth-service contract. These unsigned test
// tokens are decoded only by the UI; every API in these tests is intercepted.
const identities: Record<string, { roleId: number; authzScope: string; clientId: string }> = {
  platform_super: { roleId: 1, authzScope: 'platform', clientId: 'platform-admin' },
  platform_service: { roleId: 5, authzScope: 'platform', clientId: 'platform-admin' },
  shop_admin: { roleId: 4, authzScope: 'shop', clientId: 'shop-admin' }
}

export async function seedPlatformAdmin(page: Page, role = 'platform_super', nickname = '本地验收') {
  const identity = identities[role]
  if (!identity) throw new Error(`Unsupported platform-admin fixture role: ${role}`)
  const access: AdminAccess = {
    userId: 1, roles: [role], ...identity, accountVersion: 0, roleVersion: 0, permissions: []
  }
  const token = 'e30.' + Buffer.from(JSON.stringify({
    ...access, userType: 'admin', type: 'access', sid: `fixture-session-${role}`, exp: 4000000000
  })).toString('base64url') + '.fixture'
  await page.addInitScript(({ token, nickname }) => {
    localStorage.setItem('df_platform_admin_token', token)
    localStorage.setItem('df_platform_admin_user', JSON.stringify({ userId: 1, nickname }))
  }, { token, nickname })
  return { access, token }
}

export async function fulfillPlatformAdminAccess(route: Route, fixture: Awaited<ReturnType<typeof seedPlatformAdmin>>) {
  const request = route.request()
  if (new URL(request.url()).pathname !== '/api/v1/auth/access') return false
  if (request.method() !== 'GET' || request.headers().authorization !== `Bearer ${fixture.token}`) {
    await route.fulfill({ json: { code: 40102, message: 'token 无效' } })
    return true
  }
  await route.fulfill({ json: { code: 0, message: 'success', data: fixture.access } })
  return true
}
