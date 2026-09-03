// 商城报表接口
// 后端定义：services/operation/finance-service/api/finance.api
//   prefix: /api/v1/admin/finance （网关路由到 finance-service:8091）
//   类型 ShopReportReq / ShopReportResp 已在 .api 中声明
import type { ShopReport } from '@/types'
import { orderApi } from './order'

export interface ShopReportParams {
  startTime?: string
  endTime?: string
}

export const reportApi = {
  /** 商城报表（销售趋势 / Top 商品） */
  async shopReports(params: ShopReportParams = {}): Promise<ShopReport> {
	const report = await orderApi.report(params)
	return {
	  totalSales: report.totalSales,
	  totalOrders: report.totalOrders,
	  avgOrderValue: report.totalOrders > 0 ? report.totalSales / report.totalOrders : 0,
	  refundRate: report.refundRate,
	  salesTrend: report.trend,
	  topProducts: report.topProducts,
	}
  }
}
