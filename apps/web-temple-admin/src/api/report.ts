import client from './client'
import type { TempleReportResp } from '@/types'

/** 寺院经营报表由预约域按已支付预约聚合。 */
export function getTempleReport(params: {
  templeId: string
  startTime?: string
  endTime?: string
}): Promise<TempleReportResp> {
  return client.get<TempleReportResp>('/admin/bookings/report', { params })
}
