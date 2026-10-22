// 认证服务 API
import client from './client'
import type { LoginResp, Role, Permission, AdminAccountDetail, PageResult, AdminAccount as AccountItem } from '@/types'

export interface AdminLoginParams {
 captchaId:string
 captchaCode:string
  account: string
  password: string
}

/** 平台管理员登录 */
export function adminLogin(params: AdminLoginParams) {
  return client.post<LoginResp>('/auth/admin/login', params)
}

/** 管理台账号列表 */
export function getAdminAccounts(params: { keyword?: string; status?: string; roleId?: number; templeId?: string; masterId?: string; shopId?: number; page?: number; size?: number }) {
  return client.get<PageResult<AccountItem>>('/admin/auth/accounts', { params })
}

export function getAdminAccountDetail(id: number) {
  return client.get<AdminAccountDetail>(`/admin/auth/accounts/${id}`)
}

export function revokeAdminAccountSessions(id: number) {
  return client.post<{ id: number; success: boolean }>(`/admin/auth/accounts/${id}/revoke-sessions`)
}

export interface AdminAccountPayload {
  account: string
  password: string
  name: string
  roleId: number
  templeId?: string
  masterId?: string
  shopId?: number
}

/** 创建管理台账号并绑定所属业务主体 */
export function createAdminAccount(params: AdminAccountPayload) {
  return client.post<{ id: number }>('/admin/auth/accounts', params)
}

/** 编辑管理台账号及其主体绑定 */
export function updateAdminAccount(id: number, params: Omit<AdminAccountPayload, 'account' | 'password'>) {
  return client.put<AccountItem>(`/admin/auth/accounts/${id}`, params)
}

/** 启用或停用管理台账号 */
export function updateAdminAccountStatus(id: number, status: 'enabled' | 'disabled') {
  return client.put<{ id: number; status: string; platformDisabled: boolean }>(`/admin/auth/accounts/${id}/status`, { status })
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

export interface AdminAccess {
 userId: number; roles: string[]; clientId: string; roleId: number
 accountVersion: number; roleVersion: number; authzScope: string; permissions: string[]
}
export function getAdminAccess() { return client.get<AdminAccess>('/auth/access') }
export interface RolePermissions { roleId: number; revision: number; permissionCodes: string[]; editable: boolean }
export function getRolePermissions(id: number) { return client.get<RolePermissions>(`/admin/auth/roles/${id}/permissions`) }
export function setRolePermissions(id: number, revision: number, permissionCodes: string[]) { return client.put<RolePermissions>(`/admin/auth/roles/${id}/permissions`, { revision, permissionCodes }) }
