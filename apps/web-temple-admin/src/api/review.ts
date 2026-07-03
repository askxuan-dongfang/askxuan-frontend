import client from './client'
import type { PageResult, Review } from '@/types'

/** 评价列表（路由 /admin/reviews → review-service） */
export function listReviews(params: {
  targetType?: string
  targetId?: string
  status?: string
  rating?: number
  page?: number
  size?: number
}): Promise<PageResult<Review>> {
  return client.get<PageResult<Review>>('/admin/reviews', { params })
}

/** 评价详情 */
export function getReview(id: number): Promise<Review> {
  return client.get<Review>(`/admin/reviews/${id}`)
}

/**
 * 回复评价（POST /admin/reviews/:id/reply）
 * replierType 固定 temple_admin，replierId 取当前管理员 userId
 */
export function replyReview(id: number, replierId: string, content: string): Promise<{ id: number }> {
  return client.post<{ id: number }>(`/admin/reviews/${id}/reply`, {
    replierType: 'temple_admin',
    replierId,
    content
  })
}
