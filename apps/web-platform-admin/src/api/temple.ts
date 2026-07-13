// 寺院服务 API
import client from './client'
import type { Temple, TempleDetail, TempleAudit, BeliefProfile, PageResult } from '@/types'

export interface TempleListParams {
  beliefCode?: string
  sect?: string
  type?: string
  region?: string
  page?: number
  size?: number
}

export interface TempleAuditListParams {
  status?: string
  page?: number
  size?: number
}

/** 平台寺院列表 */
export function getTempleList(params: TempleListParams) {
  return client.get<PageResult<Temple>>('/admin/platform/temples', { params })
}

/** 寺院详情（C端接口） */
export async function getTempleDetail(id: string): Promise<TempleDetail> {
  const data = await client.get<TempleDetail | Temple>(`/temples/${id}`)
  if ('temple' in data) {
    return {
      temple: data.temple,
      images: data.images ?? [],
      services: data.services ?? []
    }
  }
  return {
    temple: data,
    images: [],
    services: []
  }
}

/** 寺院入驻审核列表 */
export function getTempleAudits(params: TempleAuditListParams) {
  return client.get<PageResult<TempleAudit>>('/admin/platform/temples/audits', { params })
}

/** 初审通过 */
export function templeAuditFirstPass(id: number, auditRemark?: string) {
  return client.put<TempleAudit>(`/admin/platform/temples/audits/${id}/first-pass`, { auditRemark })
}

/** 终审通过 */
export function templeAuditFinalPass(id: number, auditRemark?: string) {
  return client.put<TempleAudit>(`/admin/platform/temples/audits/${id}/final-pass`, { auditRemark })
}

/** 驳回 */
export function templeAuditReject(id: number, auditRemark?: string) {
  return client.put<TempleAudit>(`/admin/platform/temples/audits/${id}/reject`, { auditRemark })
}

/** 平台寺院状态变更 */
export function updateTempleStatus(id: string, status: string) {
  return client.put<{ id: string; status: string }>(`/admin/platform/temples/${id}/status`, { status })
}

export function getBelief(code: string) {
  return client.get<BeliefProfile>(`/beliefs/${code}`)
}

export function updateBelief(code: string, data: Omit<BeliefProfile, 'code'>) {
  return client.put<BeliefProfile>(`/admin/platform/beliefs/${code}`, data)
}
