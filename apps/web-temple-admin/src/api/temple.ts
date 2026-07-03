import client from './client'
import type { Temple, TempleImage, TempleService, TempleServiceListResp } from '@/types'

/** 寺院信息（管理台自有寺院，由 JWT 推导，无需传 id） */
export function getTempleInfo(): Promise<Temple> {
  return client.get<Temple>('/admin/temples/info')
}

/** 更新寺院信息 */
export function updateTempleInfo(data: Partial<Temple>): Promise<Temple> {
  return client.put<Temple>('/admin/temples/info', data)
}

/** 新增寺院图片 */
export function createTempleImage(data: {
  url: string
  type: string
  sort?: number
}): Promise<{ id: number }> {
  return client.post<{ id: number }>('/admin/temples/images', data)
}

/** 删除寺院图片 */
export function deleteTempleImage(id: number): Promise<void> {
  return client.delete<void>(`/admin/temples/images/${id}`)
}

export function getTempleImages(): Promise<{ list: TempleImage[] }> {
  return client.get<{ list: TempleImage[] }>('/admin/temples/images')
}

/** 寺院服务列表 */
export function listTempleServices(): Promise<TempleServiceListResp> {
  return client.get<TempleServiceListResp>('/admin/temples/services')
}

export function createTempleService(data: {
  serviceCode: string
  serviceName: string
  price: number
  timeSlots: string[]
}): Promise<{ id: number }> {
  return client.post<{ id: number }>('/admin/temples/services', data)
}

export function updateTempleService(
  id: number,
  data: { serviceName?: string; price?: number; timeSlots?: string[] }
): Promise<TempleService> {
  return client.put<TempleService>(`/admin/temples/services/${id}`, data)
}

export function updateTempleServiceStatus(id: number, status: string): Promise<{ id: number; status: string }> {
  return client.put<{ id: number; status: string }>(`/admin/temples/services/${id}/status`, { status })
}
