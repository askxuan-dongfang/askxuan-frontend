// 财务服务 API
import client from './client'
import type { Settlement, Withdrawal, CommissionConfig, FinanceOverview, FinanceReport, PageResult } from '@/types'

export interface SettlementParams {
  settleType?: string
  status?: string
  page?: number
  size?: number
}

/** 财务总览 */
export function getFinanceOverview(params?: { startTime?: string; endTime?: string }) {
  return client.get<FinanceOverview>('/admin/finance/overview', { params })
}

/** 结算单列表 */
export function getSettlements(params: SettlementParams) {
  return client.get<PageResult<Settlement>>('/admin/finance/settlements', { params })
}

/** 结算单详情 */
export function getSettlementDetail(id: number | string) {
  return client.get<Settlement>(`/admin/finance/settlements/${id}`)
}

/** 确认结算单 */
export function confirmSettlement(id: number | string) {
  return client.post<{ id: number; status: string }>(`/admin/finance/settlements/confirm/${id}`)
}

/** 提现申请列表 */
export function getWithdrawals(params: { applicantType?: string; status?: string; page?: number; size?: number }) {
  return client.get<PageResult<Withdrawal>>('/admin/finance/withdrawals', { params })
}

/** 提现审核 */
export function auditWithdrawal(id: number | string, params: { action: string; remark?: string }) {
  return client.put<{ id: number; status: string }>(`/admin/finance/withdrawals/${id}/audit`, params)
}

/** 提现打款 */
export function processWithdrawal(id: number | string) {
  return client.put<{ id: number; status: string }>(`/admin/finance/withdrawals/${id}/process`)
}

/** 抽成配置列表 */
export function getCommissionConfigs(params: { bizType?: string }) {
  return client.get<{ list: CommissionConfig[] }>('/admin/finance/commission-config', { params }).then((r) => r.list)
}

/** 更新抽成配置 */
export function updateCommissionConfig(id: number | string, params: { rate: number; description?: string }) {
  return client.put<{ id: number }>(`/admin/finance/commission-config/${id}`, params)
}

/** 财务报表 */
export function getFinanceReports(params: { startTime: string; endTime: string; type?: string; page?: number; size?: number }) {
  return client.get<FinanceReport>('/admin/finance/reports', { params })
}
