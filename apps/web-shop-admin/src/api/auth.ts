// 商城管理台认证接口
// 后端定义：services/platform/auth-service/api/auth.api
//   POST /api/v1/auth/admin/login （无需鉴权，NoAuthPaths 白名单内）
import client from './client'
import type { AdminLoginParams, LoginResult } from '@/types'

export const authApi = {
  /** 管理台登录（account + password） */
  adminLogin(params: AdminLoginParams): Promise<LoginResult> {
    return client.post<LoginResult>('/auth/admin/login', params)
  }
}
