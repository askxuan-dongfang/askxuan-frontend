// 问玄东方 · 商城管理台 - 工具函数
import dayjs from 'dayjs'
import { getStatusMeta } from '../../../../packages/domain-status/src'

type TagType = 'success' | 'warning' | 'info' | 'primary' | 'danger'

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
  return getStatusMeta('product', status).label
}

/**
 * 商品状态 → Element Plus Tag 类型
 */
export function productStatusType(status: string): TagType {
  return getStatusMeta('product', status).tone
}

/**
 * 订单状态 → 中文标签
 */
export function orderStatusLabel(status: string): string {
  return getStatusMeta('order', status).label
}

/**
 * 订单状态 → Element Plus Tag 类型
 */
export function orderStatusType(status: string): TagType {
  return getStatusMeta('order', status).tone
}

/**
 * DIY 订单状态 → 中文标签（对齐后端 diy_order 枚举）
 */
export function diyOrderStatusLabel(status: string): string {
  return getStatusMeta('diyOrder', status).label
}

/**
 * DIY 订单状态 → Element Plus Tag 类型
 */
export function diyOrderStatusType(status: string): TagType {
  return getStatusMeta('diyOrder', status).tone
}

/**
 * 退货状态 → 中文标签
 */
export function returnStatusLabel(status: string): string {
  return getStatusMeta('return', status).label
}

/**
 * 退货状态 → Element Plus Tag 类型
 */
export function returnStatusType(status: string): TagType {
  return getStatusMeta('return', status).tone
}

/**
 * 启用/禁用状态 → 中文
 */
export function enabledLabel(status: string): string {
  return getStatusMeta('generic', status === 'on_shelf' ? 'enabled' : status).label
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
