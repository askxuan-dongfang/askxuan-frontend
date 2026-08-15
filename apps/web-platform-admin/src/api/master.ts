// 法师服务 API
import client from './client'
import type { Master, MasterAudit, PageResult } from '@/types'

export interface MasterListParams {
  beliefCode?: string
  sect?: string
  type?: string
  templeId?: string
	 authStatus?: string
	 shelfStatus?: string
	 platformStatus?: string
  page?: number
  size?: number
}

/** 平台法师全量列表（包含待审核、下架和封禁记录） */
export function getMasterList(params: MasterListParams) {
  return client.get<PageResult<Master>>('/admin/platform/masters', { params })
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

export function updateMasterConsultation(id: string, data: {
  consultEnabled: boolean
  consultFee: number
  consultValidHours: number
  consultResponseMinutes: number
}) {
  return client.put<Master>(`/admin/platform/masters/${id}/consultation`, data)
}

/** 平台创建野生大师请求 */
export interface WildMasterCreateParams {
  dharmaName: string
  layName?: string
  position?: string
  beliefCode: string
  sect: string
  type: string
  specialties?: string[]
  avatar?: string
  consultEnabled?: boolean
  consultFee?: number
  consultValidHours?: number
  consultResponseMinutes?: number
}

/** 创建野生大师（无寺庙，平台管理） */
export function createWildMaster(data: WildMasterCreateParams): Promise<{ id: string }> {
  return client.post<{ id: string }>('/admin/platform/masters', data)
}
