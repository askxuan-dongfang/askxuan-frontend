// DIY 订单接口
// 后端定义：services/commerce/diy-service/api/diy.api
//   prefix: /api/v1/admin/diy/orders （网关路由到 diy-service:8088）
import client from './client'
import type { DiyOrder, Page } from '@/types'

export interface DiyOrderListParams {
  status?: string
  page?: number
  size?: number
}

export interface ShipParams {
  expressCompany: string
  trackingNo: string
}

export const diyOrderApi = {
  /** DIY 订单列表 */
  list(params: DiyOrderListParams = {}): Promise<Page<DiyOrder>> {
    return client.get<Page<DiyOrder>>('/admin/diy/orders', { params })
  },
  /** DIY 订单详情 */
  detail(id: number): Promise<DiyOrder> {
    return client.get<DiyOrder>(`/admin/diy/orders/${id}`)
  },
  /** DIY 订单审核 */
  review(id: number, action: 'approve' | 'reject', reason?: string): Promise<DiyOrder> {
    return client.put<DiyOrder>(`/admin/diy/orders/${id}/review`, { action, reason })
  },
  /** 制作完成 */
  makeComplete(id: number): Promise<DiyOrder> {
    return client.put<DiyOrder>(`/admin/diy/orders/${id}/make-complete`)
  },
  /** 发货 */
  ship(id: number, data: ShipParams): Promise<DiyOrder> {
    return client.put<DiyOrder>(`/admin/diy/orders/${id}/ship`, data)
  }
}
