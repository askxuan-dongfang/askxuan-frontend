export type StatusTone = 'success' | 'warning' | 'danger' | 'info' | 'primary'

export type StatusDomain =
  | 'generic'
  | 'booking'
  | 'service'
  | 'masterAuth'
  | 'temple'
  | 'review'
  | 'blessing'
  | 'product'
  | 'order'
  | 'diyOrder'
  | 'return'
  | 'payment'
  | 'content'
  | 'earning'
  | 'coupon'

export interface StatusMeta {
  label: string
  tone: StatusTone
}

const meta = (label: string, tone: StatusTone): StatusMeta => ({ label, tone })

const STATUS_DICTIONARY: Record<StatusDomain, Record<string, StatusMeta>> = {
  generic: {
    normal: meta('正常', 'success'),
    '正常': meta('正常', 'success'),
    enabled: meta('启用', 'success'),
    '启用': meta('启用', 'success'),
    disabled: meta('禁用', 'info'),
    '禁用': meta('禁用', 'info'),
    banned: meta('已封禁', 'danger'),
    '封禁': meta('已封禁', 'danger'),
    '已封禁': meta('已封禁', 'danger'),
    pending: meta('待处理', 'warning'),
    '待处理': meta('待处理', 'warning'),
    '待审核': meta('待审核', 'warning'),
    approved: meta('已通过', 'success'),
    pass: meta('已通过', 'success'),
    '已通过': meta('已通过', 'success'),
    rejected: meta('已驳回', 'danger'),
    '已驳回': meta('已驳回', 'danger'),
    handled: meta('已处理', 'success'),
    first_pass: meta('初审通过', 'success'),
    final_pass: meta('终审通过', 'success'),
    verified: meta('已认证', 'success'),
    '已认证': meta('已认证', 'success'),
    on_shelf: meta('已上架', 'success'),
    '上架': meta('已上架', 'success'),
    '已上架': meta('已上架', 'success'),
    off_shelf: meta('已下架', 'info'),
    '已下架': meta('已下架', 'info'),
    recommended: meta('推荐', 'primary'),
    '推荐': meta('推荐', 'primary'),
    confirmed: meta('已确认', 'success'),
    '已确认': meta('已确认', 'success'),
    paid: meta('已付款', 'success'),
    '已付款': meta('已付款', 'success'),
    '已支付': meta('已支付', 'success'),
    processing: meta('处理中', 'primary'),
    '处理中': meta('处理中', 'primary'),
    '进行中': meta('进行中', 'primary'),
    success: meta('成功', 'success'),
    '成功': meta('成功', 'success'),
    completed: meta('已完成', 'success'),
    '已完成': meta('已完成', 'success'),
    failed: meta('失败', 'danger'),
    '失败': meta('失败', 'danger'),
    cancelled: meta('已取消', 'danger'),
    '已取消': meta('已取消', 'danger'),
    hidden: meta('已隐藏', 'info'),
    '已隐藏': meta('已隐藏', 'info'),
    published: meta('已发布', 'success'),
    '已发布': meta('已发布', 'success'),
    offline: meta('已下线', 'info'),
    draft: meta('草稿', 'info'),
    '草稿': meta('草稿', 'info'),
    unused: meta('未使用', 'info'),
    used: meta('已使用', 'success'),
    expired: meta('已过期', 'info'),
    '待付款': meta('待付款', 'warning'),
    '待支付': meta('待支付', 'warning'),
    '待确认': meta('待确认', 'warning'),
    '待认证': meta('待认证', 'warning'),
    '待分配': meta('待分配', 'warning'),
    '待加持': meta('待加持', 'warning'),
    '待发货': meta('待发货', 'warning'),
    '退款中': meta('退款中', 'warning'),
    '退货中': meta('退货中', 'warning'),
    '退换中': meta('退换中', 'warning'),
    '制作中': meta('制作中', 'primary'),
    '加持中': meta('加持中', 'primary'),
    '加持完成': meta('加持完成', 'success'),
    '已分配': meta('已分配', 'primary'),
    '已接单': meta('已接单', 'primary'),
    '已发货': meta('已发货', 'primary'),
    '已收货': meta('已收货', 'success'),
    '退货运输中': meta('退货运输中', 'primary'),
    '已评价': meta('已评价', 'success'),
    '已拒绝': meta('已拒绝', 'danger')
  },
  booking: {
    pending_payment: meta('待支付', 'warning'),
    pending: meta('待确认', 'warning'),
    confirmed: meta('已确认', 'success'),
    in_progress: meta('进行中', 'primary'),
    completed: meta('已完成', 'success'),
    reviewed: meta('已评价', 'success'),
    cancelled: meta('已取消', 'danger')
  },
  service: {
    on_shelf: meta('已上架', 'success'),
    off_shelf: meta('已下架', 'info')
  },
  masterAuth: {
    pending: meta('待认证', 'warning'),
    unverified: meta('待认证', 'warning'),
    verified: meta('已认证', 'success'),
    pass: meta('已认证', 'success'),
    rejected: meta('已驳回', 'danger')
  },
  temple: {
    normal: meta('正常', 'success'),
    banned: meta('已封禁', 'danger'),
    recommended: meta('推荐', 'primary')
  },
  review: {
    normal: meta('正常', 'success'),
    hidden: meta('已隐藏', 'info')
  },
  blessing: {
    pending: meta('待处理', 'warning'),
    dispatched: meta('待分配', 'warning'),
    assigned: meta('已分配', 'primary'),
    accepted: meta('已接单', 'primary'),
    in_progress: meta('进行中', 'primary'),
    completed: meta('已完成', 'success'),
    rejected: meta('已拒绝', 'danger')
  },
  product: {
    draft: meta('草稿', 'info'),
    on_shelf: meta('已上架', 'success'),
    off_shelf: meta('已下架', 'warning')
  },
  order: {
    pending_payment: meta('待付款', 'warning'),
    paid: meta('已付款', 'primary'),
    shipped: meta('已发货', 'primary'),
    completed: meta('已完成', 'success'),
    cancelled: meta('已取消', 'danger'),
    in_return: meta('退货中', 'warning')
  },
  diyOrder: {
    pending_payment: meta('待付款', 'warning'),
    pending: meta('待付款', 'warning'),
    paid: meta('已付款', 'primary'),
    pending_review: meta('待审核', 'warning'),
    making: meta('制作中', 'primary'),
    in_making: meta('制作中', 'primary'),
    blessing: meta('加持中', 'primary'),
    awaiting_blessing: meta('待加持', 'info'),
    blessing_in_progress: meta('加持中', 'primary'),
    blessing_completed: meta('加持完成', 'success'),
    awaiting_shipment: meta('待发货', 'warning'),
    shipped: meta('已发货', 'primary'),
    completed: meta('已完成', 'success'),
    cancelled: meta('已取消', 'danger'),
    in_return: meta('退换中', 'warning')
  },
  return: {
    pending_review: meta('待审核', 'warning'),
    approved: meta('已通过', 'primary'),
    return_shipping: meta('退货运输中', 'primary'),
    return_received: meta('已收货', 'primary'),
    refunding: meta('退款中', 'warning'),
    completed: meta('已完成', 'success'),
    rejected: meta('已拒绝', 'danger')
  },
  payment: {
    pending: meta('待支付', 'warning'),
    pending_payment: meta('待支付', 'warning'),
    paid: meta('已支付', 'success'),
    success: meta('已支付', 'success'),
    failed: meta('支付失败', 'danger'),
    cancelled: meta('已取消', 'danger')
  },
  content: {
    draft: meta('草稿', 'info'),
    pending: meta('审核中', 'warning'),
    approved: meta('已发布', 'success'),
    published: meta('已发布', 'success'),
    rejected: meta('已驳回', 'danger'),
    off_shelf: meta('已下架', 'info')
  },
  earning: {
    pending: meta('待结算', 'warning'),
    processing: meta('结算中', 'primary'),
    settled: meta('已结算', 'success'),
    paid: meta('已打款', 'success'),
    failed: meta('结算失败', 'danger')
  },
  coupon: {
    unused: meta('未使用', 'info'),
    used: meta('已使用', 'success'),
    expired: meta('已过期', 'info')
  }
}

export function getStatusMeta(domain: StatusDomain, status?: string | null): StatusMeta {
  const value = status || ''
  return STATUS_DICTIONARY[domain][value] || STATUS_DICTIONARY.generic[value] || meta(value || '—', 'info')
}

export function isTerminalStatus(domain: StatusDomain, status: string): boolean {
  if (domain === 'booking') return ['completed', 'reviewed', 'cancelled'].includes(status)
  if (domain === 'order' || domain === 'diyOrder') return ['completed', 'cancelled'].includes(status)
  if (domain === 'return') return ['completed', 'rejected'].includes(status)
  if (domain === 'blessing') return ['completed', 'rejected'].includes(status)
  return false
}
