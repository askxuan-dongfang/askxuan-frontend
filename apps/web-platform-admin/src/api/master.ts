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

/** 平台法师详情（含野生大师与寺庙绑定大师） */
export function getPlatformMasterDetail(id: string): Promise<Master> {
  return client.get<Master>(`/admin/platform/masters/${id}`)
}

/** 平台编辑法师资料（野生大师唯一管理入口） */
export function updatePlatformMaster(
  id: string,
  data: Partial<WildMasterCreateParams>
): Promise<Master> {
  return client.put<Master>(`/admin/platform/masters/${id}`, data)
}

/** 服务目录 S001-S013（大师「可提供服务」选项） */
export interface ServiceTypeOption {
  code: string
  name: string
  type?: string
  priceRange?: string
}

/** 大师服务标签项 */
export interface MasterServiceTagItem {
  serviceCode: string
  price: number
  status?: string
}

/** 服务目录（公共接口 /service-types） */
export function getServiceTypes(): Promise<{ list: ServiceTypeOption[] }> {
  return client.get<{ list: ServiceTypeOption[] }>('/service-types')
}

/** 平台查看大师服务标签（可提供服务） */
export function getPlatformMasterServiceTags(id: string): Promise<{ list: MasterServiceTagItem[] }> {
  return client.get<{ list: MasterServiceTagItem[] }>(`/admin/platform/masters/${id}/service-tags`)
}

/** 平台配置大师服务标签（覆盖式，S001-S013 目录） */
export function updatePlatformMasterServiceTags(
  id: string,
  tags: MasterServiceTagItem[]
): Promise<{ list: MasterServiceTagItem[] }> {
  return client.put<{ list: MasterServiceTagItem[] }>(`/admin/platform/masters/${id}/service-tags`, { tags })
}
