// 商城订单接口（含发货、退货）
// 后端定义：services/commerce/order-service/api/order.api
//   prefix: /api/v1/admin/orders （网关路由到 order-service:8089）
import client from './client'
import type { Page, ReturnOrder, ShopOrder } from '@/types'

export interface OrderListParams {
  status?: string
  page?: number
  size?: number
}

export interface ShipParams {
  expressCompany: string
  trackingNo: string
}

export interface ReturnListParams {
  status?: string
  page?: number
  size?: number
}

export const orderApi = {
  /** 订单列表 */
  list(params: OrderListParams = {}): Promise<Page<ShopOrder>> {
    return client.get<Page<ShopOrder>>('/admin/orders', { params })
  },
  /** 订单详情 */
  detail(id: number): Promise<ShopOrder> {
    return client.get<ShopOrder>(`/admin/orders/${id}`)
  },
  /** 发货 */
  ship(id: number, data: ShipParams): Promise<ShopOrder> {
    return client.put<ShopOrder>(`/admin/orders/${id}/ship`, data)
  },
  /** 退货列表 */
  returnList(params: ReturnListParams = {}): Promise<Page<ReturnOrder>> {
    return client.get<Page<ReturnOrder>>('/admin/orders/returns', { params })
  },
  /** 退货审核 */
  returnReview(id: number, action: 'approve' | 'reject', reason?: string): Promise<ReturnOrder> {
    return client.put<ReturnOrder>(`/admin/orders/returns/${id}/review`, { action, reason })
  },
  /** 退款 */
  returnRefund(id: number, amount: number): Promise<ReturnOrder> {
    return client.put<ReturnOrder>(`/admin/orders/returns/${id}/refund`, { amount })
  }
}
