import type { RouteLocationResolved, RouteLocationNormalized } from 'vue-router'

// Each matched level must allow access; a broad parent cannot override a restricted child.
export function canAccessRoute(route: Pick<RouteLocationResolved | RouteLocationNormalized, 'matched'>, roles: string[]): boolean {
  return route.matched.length > 0 && route.matched.every(record => {
    const required = record.meta.roles as string[] | undefined
    return !required?.length || required.some(role => roles.includes(role))
  })
}

export function defaultRoute(roles: string[]): string {
  return roles.includes('shop_admin') && !roles.includes('platform_super') && !roles.includes('platform_service')
    ? '/commerce/dashboard' : '/dashboard'
}
