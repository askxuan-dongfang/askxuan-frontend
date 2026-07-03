// 审核服务 API
import client from './client'
import type { AuditQueue, Report, SensitiveWord, AuditStatistics, PageResult } from '@/types'

export interface AuditQueueParams {
  bizType?: string
  status?: string
  page?: number
  size?: number
}

/** 审核队列列表 */
export function getAuditQueue(params: AuditQueueParams) {
  return client.get<PageResult<AuditQueue>>('/admin/audit/queue', { params })
}

/** 审核队列详情 */
export function getAuditDetail(id: number | string) {
  return client.get<AuditQueue>(`/admin/audit/queue/${id}`)
}

/** 审核通过 */
export function approveAudit(id: number | string, params: { auditorId: string; remark?: string }) {
  return client.put<{ id: number; status: string }>(`/admin/audit/queue/${id}/approve`, params)
}

/** 审核驳回 */
export function rejectAudit(id: number | string, params: { auditorId: string; remark: string }) {
  return client.put<{ id: number; status: string }>(`/admin/audit/queue/${id}/reject`, params)
}

/** 举报列表 */
export function getAuditReports(params: { targetType?: string; status?: string; page?: number; size?: number }) {
  return client.get<PageResult<Report>>('/admin/audit/reports', { params })
}

/** 处理举报 */
export function handleAuditReport(id: number | string, params: { handlerId: string; handleResult: string; remark?: string }) {
  return client.put<{ id: number; status: string }>(`/admin/audit/reports/${id}/handle`, params)
}

/** 敏感词列表 */
export function getSensitiveWords(params: { category?: string; status?: string; keyword?: string; page?: number; size?: number }) {
  return client.get<PageResult<SensitiveWord>>('/admin/audit/sensitive-words', { params })
}

/** 新增敏感词 */
export function createSensitiveWord(params: { word: string; category: string }) {
  return client.post<{ id: number }>('/admin/audit/sensitive-words', params)
}

/** 删除敏感词 */
export function deleteSensitiveWord(id: number | string) {
  return client.delete(`/admin/audit/sensitive-words/${id}`)
}

/** 审核统计 */
export function getAuditStatistics(params: { bizType?: string }) {
  return client.get<AuditStatistics>('/admin/audit/statistics', { params })
}
