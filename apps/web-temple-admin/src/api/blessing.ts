import client from './client'
import type { BlessingTask, PageResult } from '@/types'

/** 加持任务列表（路由 /admin/temples/blessing-tasks → temple-service） */
export function listBlessingTasks(params: {
  status?: string
  page?: number
  size?: number
}): Promise<PageResult<BlessingTask>> {
  return client.get<PageResult<BlessingTask>>('/admin/temples/blessing-tasks', { params })
}

/** 加持任务详情 */
export function getBlessingTask(id: number): Promise<BlessingTask> {
  return client.get<BlessingTask>(`/admin/temples/blessing-tasks/${id}`)
}

/** 分配法师 */
export function assignBlessingTask(id: number, masterCode: string): Promise<BlessingTask> {
  return client.put<BlessingTask>(`/admin/temples/blessing-tasks/${id}/assign`, { masterCode })
}
