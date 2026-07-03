import client from './client'
import type { Master, PageResult } from '@/types'

/** 法师列表（路由 /admin/temples/masters → master-service） */
export function listMasters(params: {
  templeId: string
  status?: string
  page?: number
  size?: number
}): Promise<PageResult<Master>> {
  return client.get<PageResult<Master>>('/admin/temples/masters', { params })
}

export function createMaster(data: {
  dharmaName: string
  layName: string
  templeId: string
  templeName?: string
  position: string
  sect: string
  type: string
  specialties: string[]
  avatar?: string
}): Promise<{ id: string }> {
  return client.post<{ id: string }>('/admin/temples/masters', data)
}

export function updateMaster(
  id: string,
  data: { dharmaName?: string; layName?: string; position?: string; specialties?: string[]; avatar?: string }
): Promise<Master> {
  return client.put<Master>(`/admin/temples/masters/${id}`, data)
}

export function updateMasterStatus(id: string, status: string): Promise<{ id: string; status: string }> {
  return client.put<{ id: string; status: string }>(`/admin/temples/masters/${id}/status`, { status })
}
