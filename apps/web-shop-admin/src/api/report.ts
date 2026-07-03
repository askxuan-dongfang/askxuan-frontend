// 商城报表接口
// 后端定义：services/operation/finance-service/api/finance.api
//   prefix: /api/v1/admin/finance （网关路由到 finance-service:8091）
//   类型 ShopReportReq / ShopReportResp 已在 .api 中声明
import client from './client'
import type { ShopReport } from '@/types'

export interface ShopReportParams {
  startTime?: string
  endTime?: string
}

export const reportApi = {
  /** 商城报表（销售趋势 / Top 商品） */
  shopReports(params: ShopReportParams = {}): Promise<ShopReport> {
    return client.get<ShopReport>('/admin/finance/shop/reports', { params })
  }
}
