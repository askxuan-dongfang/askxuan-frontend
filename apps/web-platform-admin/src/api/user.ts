// 用户服务 API
import client from './client'
import type { AdminUserItem, AdminUserDetailResp, PageResult } from '@/types'

export interface UserListParams {
  keyword?: string
  status?: string
  page?: number
  size?: number
}

/** 平台用户列表 */
export function getUserList(params: UserListParams) {
  return client.get<PageResult<AdminUserItem>>('/admin/users', { params })
}

/** 用户详情 */
export function getUserDetail(id: number | string) {
  return client.get<AdminUserDetailResp>(`/admin/users/${id}`)
}

/** 更新用户状态 */
export function updateUserStatus(id: number | string, status: string) {
  return client.put<{ id: number; status: string }>(`/admin/users/${id}/status`, { status })
}
