import client from './client'
import type { Temple, TempleImage } from '@/types'

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
