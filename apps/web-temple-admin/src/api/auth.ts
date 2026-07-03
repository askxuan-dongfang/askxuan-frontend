import client from './client'
import type { LoginResp } from '@/types'

/**
 * 寺院管理员登录
 * 实际路径：POST /api/v1/auth/admin/login（网关白名单内，无需 JWT）
 * 后端 AdminLoginReq 仅接受 account + password，角色由账号本身决定。
 */
export function adminLogin(account: string, password: string): Promise<LoginResp> {
  return client.post<LoginResp>('/auth/admin/login', { account, password })
}
