import dayjs from 'dayjs'
import type { TagProps } from 'element-plus'
import { getStatusMeta, isTerminalStatus, type StatusDomain } from '../../../../packages/domain-status/src'

/** 日期格式化，兼容 ISO / yyyy-MM-dd HH:mm:ss */
export function formatDate(value?: string | number | Date | null, withTime = true): string {
  if (!value) return '-'
  const d = dayjs(value)
  if (!d.isValid()) return String(value)
  return withTime ? d.format('YYYY-MM-DD HH:mm') : d.format('YYYY-MM-DD')
}

/** 金额格式化（元，2 位小数） */
export function formatMoney(n?: number | null): string {
  if (n === null || n === undefined || Number.isNaN(n)) return '¥0.00'
  return '¥' + Number(n).toFixed(2)
}

/** 百分比 */
export function formatPercent(n?: number | null, digits = 1): string {
  if (n === null || n === undefined || Number.isNaN(n)) return '0%'
  return Number(n).toFixed(digits) + '%'
}

// ============ 预约状态 ============
export function bookingStatusText(status: string): string {
  return getStatusMeta('booking', status).label
}

export function bookingStatusType(status: string): TagProps['type'] {
  return getStatusMeta('booking', status).tone
}

/** 终态：已评价 / 已取消 */
export function isBookingTerminal(status: string): boolean {
  return isTerminalStatus('booking', status)
}

// ============ 服务上下架 ============
export function serviceStatusText(status: string): string {
  return getStatusMeta('service', status).label
}

export function serviceStatusType(status: string): TagProps['type'] {
  return getStatusMeta('service', status).tone
}

function statusText(domain: StatusDomain, status: string): string {
  return getStatusMeta(domain, status).label
}

// ============ 法师认证状态 ============
export function masterAuthStatusText(status: string): string {
  return statusText('masterAuth', status)
}

// ============ 寺院状态 ============
export function templeStatusText(status: string): string {
  return statusText('temple', status)
}

// ============ 评价状态 ============
export function reviewStatusText(status: string): string {
  return statusText('review', status)
}

export function reviewStatusType(status: string): TagProps['type'] {
  return getStatusMeta('review', status).tone
}

// ============ 加持任务状态 ============
export function blessingStatusText(status: string): string {
  return statusText('blessing', status)
}

// ============ 评价图片解析 ============
/** review.images 是 JSON 数组字符串，booking.images 已是数组；统一转 string[] */
export function parseImages(images: string | string[] | null | undefined): string[] {
  if (!images) return []
  if (Array.isArray(images)) return images
  try {
    const parsed = JSON.parse(images)
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}
