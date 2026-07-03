import client from './client'
import type { TempleReportResp } from '@/types'

/** 寺院数据报表（路由 /admin/temples/reports → temple-service） */
export function getTempleReport(params?: {
  startTime?: string
  endTime?: string
}): Promise<TempleReportResp> {
  return client.get<TempleReportResp>('/admin/temples/reports', { params })
}
