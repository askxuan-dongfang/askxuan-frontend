// 物流接口（快递公司 / 运费模板 / 物流追踪）
// 后端定义：services/operation/logistics-service/api/logistics.api
//   prefix: /api/v1/admin/logistics （网关路由到 logistics-service:8095）
import client from './client'
import type { ExpressCompany, FreightTemplate, Page, TrackQueryResp } from '@/types'

export interface ExpressListParams {
  code?: string
  name?: string
  status?: string
  page?: number
  size?: number
}

export interface ExpressCreateParams {
  code: string
  name: string
  logoUrl?: string
  customerService?: string
  sort?: number
}

export interface ExpressUpdateParams {
  name?: string
  logoUrl?: string
  customerService?: string
  sort?: number
  status?: 'enabled' | 'disabled'
}

export interface FreightTemplateListParams {
  name?: string
  type?: string
  status?: string
  page?: number
  size?: number
}

export interface FreightTemplateCreateParams {
  name: string
  type: 'by_weight' | 'by_piece'
  freeShipping?: number
  config: string
}

export interface FreightTemplateUpdateParams {
  name?: string
  type?: 'by_weight' | 'by_piece'
  freeShipping?: number
  config?: string
  status?: 'enabled' | 'disabled'
}

export const logisticsApi = {
  /* ===== 快递公司 ===== */
  expressList(params: ExpressListParams = {}): Promise<Page<ExpressCompany>> {
    return client.get<Page<ExpressCompany>>('/admin/logistics/express', { params })
  },
  expressCreate(data: ExpressCreateParams): Promise<{ id: number }> {
    return client.post<{ id: number }>('/admin/logistics/express', data)
  },
  expressUpdate(id: number, data: ExpressUpdateParams): Promise<void> {
    return client.put<void>(`/admin/logistics/express/${id}`, data)
  },

  /* ===== 运费模板 ===== */
  freightTemplateList(params: FreightTemplateListParams = {}): Promise<Page<FreightTemplate>> {
    return client.get<Page<FreightTemplate>>('/admin/logistics/freight-templates', { params })
  },
  freightTemplateCreate(data: FreightTemplateCreateParams): Promise<{ id: number }> {
    return client.post<{ id: number }>('/admin/logistics/freight-templates', data)
  },
  freightTemplateUpdate(id: number, data: FreightTemplateUpdateParams): Promise<void> {
    return client.put<void>(`/admin/logistics/freight-templates/${id}`, data)
  },

  /* ===== 物流追踪 ===== */
  trackQuery(trackingNo: string): Promise<TrackQueryResp> {
    return client.get<TrackQueryResp>(`/admin/logistics/tracks/${trackingNo}`)
  },
  tracksBatchSync(trackingNos?: string[]): Promise<{ total: number; success: number; failed: number }> {
    return client.post<{ total: number; success: number; failed: number }>(
      '/admin/logistics/tracks/batch-sync',
      { trackingNos }
    )
  }
}
