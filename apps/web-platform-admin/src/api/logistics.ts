// 物流服务 API（平台总管理台预留模块）
import client from './client'
import type { PageResult } from '@/types'

export interface LogisticsItem {
  id: number
  orderNo: string
  logisticsNo: string
  company: string
  status: string
  receiver: string
  phone: string
  address: string
  createTime: string
}

export function getLogisticsList(params: { status?: string; keyword?: string; page?: number; size?: number }) {
  return client.get<PageResult<LogisticsItem>>('/admin/logistics', { params })
}
