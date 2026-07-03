// 祈福服务接口（DIY 加持服务）
// 后端定义：services/commerce/diy-service/api/diy.api
//   prefix: /api/v1/admin/diy/blessing-services （网关路由到 diy-service:8088）
import client from './client'
import type { BlessingService, Page } from '@/types'

export interface BlessingServiceListParams {
  page?: number
  size?: number
}

export interface BlessingServiceSaveParams {
  serviceName: string
  templeCode: string
  masterCode: string
  price: number
  description?: string
  status?: 'on_shelf' | 'off_shelf'
}

export const serviceApi = {
  /** 祈福服务列表 */
  list(params: BlessingServiceListParams = {}): Promise<Page<BlessingService>> {
    return client.get<Page<BlessingService>>('/admin/diy/blessing-services', { params })
  },
  /** 创建祈福服务 */
  create(data: BlessingServiceSaveParams): Promise<{ id: number }> {
    return client.post<{ id: number }>('/admin/diy/blessing-services', data)
  },
  /** 更新祈福服务 */
  update(id: number, data: BlessingServiceSaveParams): Promise<BlessingService> {
    return client.put<BlessingService>(`/admin/diy/blessing-services/${id}`, data)
  },
  /** 删除祈福服务 */
  remove(id: number): Promise<void> {
    return client.delete<void>(`/admin/diy/blessing-services/${id}`)
  }
}
