// 问玄东方 P05 平台总管理台 - 格式化工具
import dayjs from 'dayjs'

/** 金额格式化：分/元 -> 千分位字符串 */
export function formatMoney(value: number | string | undefined | null, prefix = '¥'): string {
  const num = Number(value ?? 0)
  if (isNaN(num)) return `${prefix}0.00`
  return `${prefix}${num.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
}

/** 数字千分位 */
export function formatNumber(value: number | string | undefined | null): string {
  const num = Number(value ?? 0)
  if (isNaN(num)) return '0'
  return num.toLocaleString('zh-CN')
}

/** 百分比 */
export function formatPercent(value: number | undefined | null, digits = 1): string {
  const num = Number(value ?? 0)
  if (isNaN(num)) return '0%'
  return `${(num * 100).toFixed(digits)}%`
}

/** 日期格式化 */
export function formatDate(value: string | number | undefined | null, fmt = 'YYYY-MM-DD HH:mm'): string {
  if (!value) return '-'
  const d = dayjs(value)
  return d.isValid() ? d.format(fmt) : '-'
}

/** 仅日期 */
export function formatDateOnly(value: string | number | undefined | null): string {
  return formatDate(value, 'YYYY-MM-DD')
}

/** 手机号脱敏 */
export function maskMobile(mobile: string | undefined | null): string {
  if (!mobile) return '-'
  const s = String(mobile)
  if (s.length < 7) return s
  return s.replace(/(\d{3})\d{4}(\d{4})/, '$1****$2')
}

/** 银行卡脱敏 */
export function maskBankCard(card: string | undefined | null): string {
  if (!card) return '-'
  const s = String(card)
  if (s.length < 8) return s
  return s.slice(0, 4) + ' **** **** ' + s.slice(-4)
}

/** JSON 字符串解析为对象，失败返回原值 */
export function safeJsonParse<T = unknown>(str: string | undefined | null, fallback: T): T {
  if (!str) return fallback
  try {
    return JSON.parse(str) as T
  } catch {
    return fallback
  }
}

/** 截断文本 */
export function truncate(text: string | undefined | null, len = 30): string {
  if (!text) return '-'
  return text.length > len ? text.slice(0, len) + '…' : text
}
