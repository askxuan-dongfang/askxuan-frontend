import client from './client'
import type { ServiceTypeOption, TempleService, TempleServiceListResp, TempleServiceSlot } from '@/types'

export function listServiceTypes(): Promise<{ list: ServiceTypeOption[] }> {
  return client.get<{ list: ServiceTypeOption[] }>('/service-types')
}

/**
 * 寺院服务管理（路由 /admin/temples/services → temple-service）
 * 与 temple.ts 中的服务方法语义一致，此处单独导出便于按模块引用。
 */
export function listServices(): Promise<TempleServiceListResp> {
  return client.get<TempleServiceListResp>('/admin/temples/services')
}

/** 寺院服务详情 */
export function getServiceDetail(id: number): Promise<TempleService> {
  return client.get<TempleService>(`/admin/temples/services/${id}`)
}

export function createService(data: {
  serviceCode: string
  price: number
  timeSlots: string[]
	slots: TempleServiceSlot[]
  intentTags?: string[]
}): Promise<{ id: number }> {
  return client.post<{ id: number }>('/admin/temples/services', data)
}

export function updateService(
  id: number,
	data: { price?: number; timeSlots?: string[]; slots?: TempleServiceSlot[]; intentTags?: string[] }
): Promise<TempleService> {
  return client.put<TempleService>(`/admin/temples/services/${id}`, data)
}

export function updateServiceStatus(id: number, status: string): Promise<{ id: number; status: string }> {
  return client.put<{ id: number; status: string }>(`/admin/temples/services/${id}/status`, { status })
}
