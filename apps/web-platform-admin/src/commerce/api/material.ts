// DIY 材料接口
// 后端定义：services/commerce/diy-service/api/diy.api
//   prefix: /api/v1/admin/diy/materials （网关路由到 diy-service:8088）
import client from '@/api/client'
import type { Material, Page } from '@/commerce/types'

export interface MaterialListParams {
  category?: string
  keyword?: string
  page?: number
  size?: number
}

export type StudioMaterial = Material & { renderAssets?: string }

export interface MaterialSaveParams {
  renderAssets?: string
  name: string
  spec: string
  unitPrice: number
  unit: string
  category: string
  fiveElements?: string
  materialType: string
  shape: string
  diameterMm: number
  colorHex: string
  textureKey: string
  finish: string
  translucency: number
  image: string
  stock: number
}

export const materialApi = {
  /** 材料列表 */
  list(params: MaterialListParams = {}): Promise<Page<StudioMaterial>> {
    return client.get<Page<StudioMaterial>>('/admin/diy/materials', { params })
  },
  /** 材料详情 */
  detail(id: number): Promise<StudioMaterial> {
    return client.get<StudioMaterial>(`/admin/diy/materials/${id}`)
  },
  /** 创建材料 */
  create(data: MaterialSaveParams): Promise<{ id: number }> {
    return client.post<{ id: number }>('/admin/diy/materials', data)
  },
  /** 更新材料 */
  update(id: number, data: MaterialSaveParams): Promise<StudioMaterial> {
    return client.put<StudioMaterial>(`/admin/diy/materials/${id}`, data)
  },
  /** 上下架 */
  updateStatus(id: number, status: 'on_shelf' | 'off_shelf'): Promise<StudioMaterial> {
    return client.put<StudioMaterial>(`/admin/diy/materials/${id}/status`, { status })
  }
}
