// JWT 前端解码工具（仅解 payload，不验签；签名校验由网关/后端完成）
// 用途：路由级 RBAC —— 从 accessToken 的 payload 中读取 roles / clientId。

export interface JwtPayload {
  userId?: number
  userType?: string
  roles?: string[]
  clientId?: string
  exp?: number
  [key: string]: unknown
}

function base64UrlDecode(input: string): string {
  const base64 = input.replace(/-/g, '+').replace(/_/g, '/')
  const padded = base64 + '='.repeat((4 - (base64.length % 4)) % 4)
  const binary = atob(padded)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  return new TextDecoder('utf-8').decode(bytes)
}

/** 解码 JWT payload；格式非法时返回 null */
export function decodeJwtPayload(token: string): JwtPayload | null {
  try {
    const parts = token.split('.')
    if (parts.length !== 3) return null
    const payload = JSON.parse(base64UrlDecode(parts[1]))
    return payload && typeof payload === 'object' ? (payload as JwtPayload) : null
  } catch {
    return null
  }
}

/** 提取 JWT 中的角色列表（customer/temple_admin/master/shop_admin/platform_super/platform_service） */
export function jwtRoles(token: string): string[] {
  const payload = decodeJwtPayload(token)
  const roles = payload?.roles
  if (!Array.isArray(roles)) return []
  return roles.filter((r): r is string => typeof r === 'string')
}

/** 提取 JWT 中的端标识 clientId（customer/temple-admin/master/shop-admin/platform-admin） */
export function jwtClientId(token: string): string {
  const clientId = decodeJwtPayload(token)?.clientId
  return typeof clientId === 'string' ? clientId : ''
}

/** 判断 JWT 是否已过期（无 exp 字段时视为未过期，交由后端 401 兜底） */
export function jwtExpired(token: string): boolean {
  const exp = decodeJwtPayload(token)?.exp
  if (typeof exp !== 'number') return false
  return Date.now() >= exp * 1000
}
