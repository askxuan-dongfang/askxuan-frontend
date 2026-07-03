import dayjs from 'dayjs'
import type { TagProps } from 'element-plus'

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
export const BOOKING_STATUS = {
  pending: '待确认',
  confirmed: '已确认',
  in_progress: '进行中',
  reviewed: '已评价',
  cancelled: '已取消'
} as const

export function bookingStatusText(status: string): string {
  return (BOOKING_STATUS as Record<string, string>)[status] ?? status
}

export function bookingStatusType(status: string): TagProps['type'] {
  const map: Record<string, TagProps['type']> = {
    pending: 'warning',
    confirmed: 'success',
    in_progress: 'primary',
    reviewed: 'info',
    cancelled: 'danger'
  }
  return map[status] ?? 'info'
}

/** 终态：已评价 / 已取消 */
export function isBookingTerminal(status: string): boolean {
  return status === 'reviewed' || status === 'cancelled'
}

// ============ 服务上下架 ============
export const SERVICE_STATUS = {
  on_shelf: '上架',
  off_shelf: '下架'
} as const

export function serviceStatusText(status: string): string {
  return (SERVICE_STATUS as Record<string, string>)[status] ?? status
}

export function serviceStatusType(status: string): TagProps['type'] {
  return status === 'on_shelf' ? 'success' : 'info'
}

// ============ 法师认证状态 ============
export function masterAuthStatusText(status: string): string {
  const map: Record<string, string> = {
    pending: '待认证',
    unverified: '待认证',
    verified: '已认证',
    pass: '已认证',
    rejected: '已驳回'
  }
  return map[status] ?? status
}

// ============ 寺院状态 ============
export function templeStatusText(status: string): string {
  const map: Record<string, string> = {
    normal: '正常',
    banned: '已封禁',
    recommended: '推荐'
  }
  return map[status] ?? status
}

// ============ 评价状态 ============
export function reviewStatusText(status: string): string {
  const map: Record<string, string> = {
    normal: '正常',
    hidden: '已隐藏'
  }
  return map[status] ?? status
}

export function reviewStatusType(status: string): TagProps['type'] {
  return status === 'normal' ? 'success' : 'info'
}

// ============ 加持任务状态 ============
export function blessingStatusText(status: string): string {
  const map: Record<string, string> = {
    pending: '待处理',
    assigned: '已分配',
    in_progress: '进行中',
    completed: '已完成',
    rejected: '已拒绝'
  }
  return map[status] ?? status
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
