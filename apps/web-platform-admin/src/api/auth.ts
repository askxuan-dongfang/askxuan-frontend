// 认证服务 API
import client from './client'
import type { LoginResp, Role, Permission, AdminAccount, PageResult, AdminAccount as AccountItem } from '@/types'

export interface AdminLoginParams {
  account: string
  password: string
}

/** 平台管理员登录 */
export function adminLogin(params: AdminLoginParams) {
  return client.post<LoginResp>('/auth/admin/login', params)
}

/** 管理台账号列表 */
export function getAdminAccounts(params: { keyword?: string; status?: string; page?: number; size?: number }) {
  return client.get<PageResult<AccountItem>>('/admin/auth/accounts', { params })
}

/** 角色列表 */
export function getRoles() {
  return client.get<{ list: Role[] }>('/admin/auth/roles').then((r) => r.list)
}

/** 创建角色 */
export function createRole(params: { name: string; code: string; description?: string }) {
  return client.post<{ id: number }>('/admin/auth/roles', params)
}

/** 更新角色 */
export function updateRole(id: number, params: { name?: string; description?: string }) {
  return client.put<Role>(`/admin/auth/roles/${id}`, params)
}

/** 权限列表 */
export function getPermissions() {
  return client.get<{ list: Permission[] }>('/admin/auth/permissions').then((r) => r.list)
}

export type { AccountItem }
