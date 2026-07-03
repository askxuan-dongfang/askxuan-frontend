// 系统设置 API（角色权限 / 数据字典 / 操作日志）
import client from './client'
import type { Role, Permission, AuditQueue, SensitiveWord, PageResult } from '@/types'

// 角色 & 权限（来自 auth-service）
export { getRoles, createRole, updateRole, getPermissions, getAdminAccounts } from './auth'

// 数据字典：复用 audit-service 敏感词管理
export { getSensitiveWords, createSensitiveWord, deleteSensitiveWord } from './audit'

// 操作日志：复用 audit-service 审核队列（全量记录）
export function getOperationLogs(params: { bizType?: string; status?: string; page?: number; size?: number }) {
  return client.get<PageResult<AuditQueue>>('/admin/audit/queue', { params })
}

export type { Role, Permission, SensitiveWord, AuditQueue }
