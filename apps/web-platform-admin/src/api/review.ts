// 评价服务 API
import client from './client'
import type { Review, ReviewReport, PageResult } from '@/types'

export interface ReviewListParams {
  targetType?: string
  targetId?: string
  status?: string
  rating?: number
  page?: number
  size?: number
}

/** 评价列表 */
export function getReviewList(params: ReviewListParams) {
  return client.get<PageResult<Review>>('/admin/reviews', { params })
}

/** 评价详情 */
export function getReviewDetail(id: number | string) {
  return client.get<Review>(`/admin/reviews/${id}`)
}

/** 回复评价 */
export function replyReview(id: number | string, params: { replierType: string; replierId: string; content: string }) {
  return client.post<{ id: number }>(`/admin/reviews/${id}/reply`, params)
}

/** 平台举报列表 */
export function getReportList(params: { status?: string; page?: number; size?: number }) {
  return client.get<PageResult<ReviewReport>>('/admin/platform/reviews/reports', { params })
}

/** 处理举报 */
export function handleReport(id: number | string, params: { handleResult: string; remark?: string }) {
  return client.put<{ id: number; status: string }>(`/admin/platform/reviews/reports/${id}/handle`, params)
}
