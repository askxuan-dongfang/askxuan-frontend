import type { RouteLocationResolved, RouteLocationNormalized } from 'vue-router'

export interface PlatformAccess { authzScope: string; clientId: string; permissions: string[] }
const fixedRoles = ['platform_super', 'platform_service', 'shop_admin', 'temple_admin', 'master', 'customer', 'temple_applicant', 'master_applicant']
export function isDelegatedPlatform(roles: string[], access?: PlatformAccess | null): boolean {
  return access?.authzScope === 'platform' && access.clientId === 'platform-admin' && roles.length === 1 && !fixedRoles.includes(roles[0])
}

// Every matched level must authorize the route. A broad shell never unlocks a child.
export function canAccessRoute(route: Pick<RouteLocationResolved | RouteLocationNormalized, 'matched'>, roles: string[], access?: PlatformAccess | null): boolean {
  const delegated = isDelegatedPlatform(roles, access)
  return route.matched.length > 0 && route.matched.every(record => {
    if (record.meta.superOnly) return roles.includes('platform_super')
    if (record.meta.platformShell && delegated) return true
    if (record.meta.emptyAccess && delegated) return true
    const required = record.meta.roles as string[] | undefined
    if (required?.some(role => roles.includes(role))) return true
    if (delegated) {
      const permissions = record.meta.permissions as string[] | undefined
      return !!permissions?.length && permissions.every(code => access!.permissions.includes(code))
    }
    return !required?.length
  })
}

const delegatedLanding: [string, string][] = [
  ['platform.temples.read', '/temple/list'], ['platform.masters.read', '/master/list'],
  ['platform.users.read', '/user/list'], ['platform.products.read', '/commerce/products'],
  ['platform.orders.read', '/commerce/orders'], ['platform.diy.read', '/commerce/materials'],
  ['platform.points.read', '/commerce/points-mall'], ['platform.logistics.read', '/commerce/logistics'],
  ['platform.finance.read', '/finance/overview'], ['platform.marketing.read', '/marketing/banner'],
  ['platform.moderation.read', '/audit/report'], ['platform.operations.read', '/settings/log']
]
export function defaultRoute(roles: string[], access?: PlatformAccess | null): string {
  if (isDelegatedPlatform(roles, access)) return delegatedLanding.find(([code]) => access!.permissions.includes(code))?.[1] || '/access-denied'
  return roles.includes('shop_admin') && !roles.includes('platform_super') && !roles.includes('platform_service') ? '/commerce/dashboard' : '/dashboard'
}
