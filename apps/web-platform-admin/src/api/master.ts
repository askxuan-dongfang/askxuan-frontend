// 法师服务 API
import client from './client'
import type { Master, MasterAudit, PageResult } from '@/types'

export interface MasterListParams {
  sect?: string
  type?: string
  templeId?: string
  page?: number
  size?: number
}

/** 法师列表（C端接口） */
export function getMasterList(params: MasterListParams) {
  return client.get<PageResult<Master>>('/masters', { params })
}

/** 法师详情（C端接口） */
export function getMasterDetail(id: string) {
  return client.get<Master>(`/masters/${id}`)
}

/** 法师资质审核列表 */
export function getMasterAudits(params: { status?: string; page?: number; size?: number }) {
  return client.get<PageResult<MasterAudit>>('/admin/platform/masters/audits', { params })
}

/** 法师审核通过 */
export function masterAuditPass(id: number, auditRemark?: string) {
  return client.put<MasterAudit>(`/admin/platform/masters/audits/${id}/pass`, { auditRemark })
}

/** 法师审核驳回 */
export function masterAuditReject(id: number, auditRemark?: string) {
  return client.put<MasterAudit>(`/admin/platform/masters/audits/${id}/reject`, { auditRemark })
}

/** 平台法师状态变更 */
export function updateMasterStatus(id: string, status: string) {
  return client.put<{ id: string; status: string }>(`/admin/platform/masters/${id}/status`, { status })
}
