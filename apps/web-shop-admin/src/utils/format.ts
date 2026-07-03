// 问玄东方 · 商城管理台 - 工具函数
import dayjs from 'dayjs'

/**
 * 格式化日期为 YYYY-MM-DD
 */
export function formatDate(date: string | Date | undefined | null): string {
  if (!date) return '-'
  return dayjs(date).format('YYYY-MM-DD')
}

/**
 * 格式化日期时间为 YYYY-MM-DD HH:mm
 */
export function formatDateTime(date: string | Date | undefined | null): string {
  if (!date) return '-'
  return dayjs(date).format('YYYY-MM-DD HH:mm')
}

/**
 * 格式化金额（人民币）
 */
export function formatMoney(amount: number | undefined | null): string {
  if (amount === undefined || amount === null) return '¥0'
  return `¥${Number(amount).toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

/**
 * 商品状态 → 中文标签
 */
export function productStatusLabel(status: string): string {
  const map: Record<string, string> = {
    draft: '草稿',
    on_shelf: '已上架',
    off_shelf: '已下架'
  }
  return map[status] ?? status
}

/**
 * 商品状态 → Element Plus Tag 类型
 */
export function productStatusType(status: string): 'success' | 'warning' | 'info' | 'primary' | 'danger' {
  const map: Record<string, 'success' | 'warning' | 'info' | 'primary' | 'danger'> = {
    draft: 'info',
    on_shelf: 'success',
    off_shelf: 'warning'
  }
  return map[status] ?? 'info'
}

/**
 * 订单状态 → 中文标签
 */
export function orderStatusLabel(status: string): string {
  const map: Record<string, string> = {
    pending_payment: '待付款',
    paid: '已付款',
    shipped: '已发货',
    completed: '已完成',
    cancelled: '已取消',
    in_return: '退货中'
  }
  return map[status] ?? status
}

/**
 * 订单状态 → Element Plus Tag 类型
 */
export function orderStatusType(status: string): 'success' | 'warning' | 'info' | 'primary' | 'danger' {
  const map: Record<string, 'success' | 'warning' | 'info' | 'primary' | 'danger'> = {
    pending_payment: 'warning',
    paid: 'primary',
    shipped: 'info',
    completed: 'success',
    cancelled: 'danger',
    in_return: 'warning'
  }
  return map[status] ?? 'info'
}

/**
 * 退货状态 → 中文标签
 */
export function returnStatusLabel(status: string): string {
  const map: Record<string, string> = {
    pending_review: '待审核',
    approved: '已通过',
    return_shipping: '退货运输中',
    return_received: '已收货',
    refunding: '退款中',
    completed: '已完成',
    rejected: '已拒绝'
  }
  return map[status] ?? status
}

/**
 * 退货状态 → Element Plus Tag 类型
 */
export function returnStatusType(status: string): 'success' | 'warning' | 'info' | 'primary' | 'danger' {
  const map: Record<string, 'success' | 'warning' | 'info' | 'primary' | 'danger'> = {
    pending_review: 'warning',
    approved: 'primary',
    return_shipping: 'info',
    return_received: 'info',
    refunding: 'warning',
    completed: 'success',
    rejected: 'danger'
  }
  return map[status] ?? 'info'
}

/**
 * 启用/禁用状态 → 中文
 */
export function enabledLabel(status: string): string {
  return status === 'enabled' || status === 'on_shelf' ? '启用' : '禁用'
}

/**
 * 材料分类 → 中文标签
 */
export function materialCategoryLabel(category: string): string {
  const map: Record<string, string> = {
    main_bead: '主珠',
    spacer: '隔珠',
    buddha_head: '佛头',
    pendant: '吊坠',
    tassel: '流苏',
    three_way: '三通',
    cord: '线绳'
  }
  return map[category] ?? category
}

/**
 * 取姓名首字（用于头像占位）
 */
export function nameInitial(name: string): string {
  return name ? name.charAt(0) : '?'
}
