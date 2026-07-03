// 通信服务 API（message-service 返回原始 JSON，client 已兼容无 code 包装场景）
import client from './client'
import type { MessageTemplate, SystemAnnouncement, PageResult } from '@/types'

/** 消息模板列表 */
export function getTemplates(params: { type?: string; page?: number; size?: number }) {
  return client.get<PageResult<MessageTemplate>>('/admin/messages/templates', { params })
}

/** 创建消息模板 */
export function createTemplate(params: {
  code: string
  titleTemplate: string
  contentTemplate: string
  variables?: string
  type: string
}) {
  return client.post<{ id: number }>('/admin/messages/templates', params)
}

/** 更新消息模板 */
export function updateTemplate(id: number | string, params: Partial<MessageTemplate>) {
  return client.put<{ id: number }>(`/admin/messages/templates/${id}`, params)
}

/** 发送推送 */
export function pushMessage(params: {
  userId: string
  pushType: string
  title: string
  content: string
  bizType?: string
  bizId?: string
}) {
  return client.post<{ pushLogId: number; status: string }>('/admin/messages/push', params)
}

/** 系统公告列表 */
export function getAnnouncements(params: { type?: string; targetAudience?: string; page?: number; size?: number }) {
  return client.get<PageResult<SystemAnnouncement>>('/admin/announcements/list', { params })
}

/** 创建系统公告 */
export function createAnnouncement(params: {
  title: string
  content: string
  type: string
  targetAudience: string
}) {
  return client.post<{ id: number }>('/admin/announcements/create', params)
}

/** 公告状态变更 */
export function updateAnnouncementStatus(id: number | string, status: string) {
  return client.put<{ id: number }>(`/admin/announcements/${id}/status`, { status })
}
