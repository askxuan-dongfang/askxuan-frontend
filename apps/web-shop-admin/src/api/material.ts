// DIY 材料接口
// 后端定义：services/commerce/diy-service/api/diy.api
//   prefix: /api/v1/admin/diy/materials （网关路由到 diy-service:8088）
import client from './client'
import type { Material, Page } from '@/types'

export interface MaterialListParams {
  category?: string
  keyword?: string
  page?: number
  size?: number
}

export interface MaterialSaveParams {
  name: string
  spec: string
  unitPrice: number
  unit: string
  category: string
  fiveElements?: string
  image: string
  stock: number
}

export const materialApi = {
  /** 材料列表 */
  list(params: MaterialListParams = {}): Promise<Page<Material>> {
    return client.get<Page<Material>>('/admin/diy/materials', { params })
  },
  /** 创建材料 */
  create(data: MaterialSaveParams): Promise<{ id: number }> {
    return client.post<{ id: number }>('/admin/diy/materials', data)
  },
  /** 更新材料 */
  update(id: number, data: MaterialSaveParams): Promise<Material> {
    return client.put<Material>(`/admin/diy/materials/${id}`, data)
  },
  /** 上下架 */
  updateStatus(id: number, status: 'on_shelf' | 'off_shelf'): Promise<Material> {
    return client.put<Material>(`/admin/diy/materials/${id}/status`, { status })
  }
}
