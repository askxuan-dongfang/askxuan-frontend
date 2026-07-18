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

export interface BackupItem {
  id: string
  filename: string
  size: number
  sizeBytes: number
  type: 'auto' | 'manual'
  status: string
  time: string
  objectName: string
}

export function getBackups() {
  return client.get<{ list: BackupItem[] }>('/admin/files/backups')
}

export function createBackup() {
  return client.post<BackupItem>('/admin/files/backups', undefined, { timeout: 660_000 })
}

export function getBackupDownload(filename: string) {
  return client.get<{ url: string; expiresIn: number }>(`/admin/files/backups/${encodeURIComponent(filename)}/download`)
}

export function restoreBackup(filename: string, confirm: string) {
  return client.post<{ success: boolean; message: string }>(
    `/admin/files/backups/${encodeURIComponent(filename)}/restore`,
    { confirm },
    { timeout: 660_000 }
  )
}
