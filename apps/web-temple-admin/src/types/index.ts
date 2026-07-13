// 问玄东方 · 寺院管理台 - 全局类型定义

/** 统一响应结构（client.ts 拦截器已解包返回 data 字段） */
export interface ApiResponse<T = unknown> {
  code: number
  message: string
  data: T
}

/** 分页结果 */
export interface PageResult<T> {
  total: number
  list: T[]
  page: number
  size: number
}

/** 通用分页请求 */
export interface PageQuery {
  page?: number
  size?: number
}

// ============ 认证 ============
export interface UserInfo {
  userId: number
  nickname: string
  avatar: string
  mobile: string
  /** 部分账号返回 templeId，缺省时由前端 localStorage 兜底 */
  templeId?: string
  templeName?: string
}

export interface LoginResp {
  accessToken: string
  refreshToken: string
  expiresIn: number
  userInfo: UserInfo
  imToken?: string
}

// ============ 寺院 ============
export interface Temple {
  id: string
  name: string
  region: string
  type: string
  beliefCode: string
  sect: string
  status: string
  address: string
  coverImage: string
  rating: number
  description: string
}

export interface TempleImage {
  id: number
  templeCode: string
  url: string
  type: string // cover/detail/hero
  sort: number
  createTime: string
}

export interface TempleService {
  id: number
  templeCode: string
  serviceCode: string
  serviceName: string
  price: number
  timeSlots: string[]
  intentTags: string[]
  status: string // on_shelf/off_shelf
  createTime: string
}

export interface TempleServiceListResp {
  list: TempleService[]
}

// ============ 法师 ============
export interface Master {
  id: string
  dharmaName: string
  layName: string
  templeId: string
  templeName: string
  position: string
  beliefCode: string
  sect: string
  type: string
  authStatus: string
  specialties: string[]
  avatar: string
  rating: number
}

// ============ 预约 ============
export interface Booking {
  id: string
  userId: string
  templeId: string
  templeName: string
  masterId: string
  masterName: string
  serviceId: string
  serviceName: string
  bookingDate: string
  timeSlot: string
  meritMoney: number
  meritMoneyTier: string
  status: string
  note: string
  createdAt: string
}

export interface BookingStatusLog {
  id: number
  bookingId: string
  fromStatus: string
  toStatus: string
  operatorId: string
  operatorType: string // user/temple_admin/system
  remark: string
  createTime: string
}

export interface BookingReview {
  id: number
  bookingId: string
  userId: string
  rating: number
  content: string
  images: string[]
  masterReply: string
  createTime: string
}

// ============ 评价（review-service） ============
export interface Review {
  id: number
  reviewNo: string
  userId: string
  targetType: string // booking/diy_order/shop_order
  targetId: string
  rating: number
  content: string
  images: string // JSON 数组字符串
  status: string // normal/hidden
  createTime: string
}

// ============ 加持任务 ============
export interface BlessingTask {
  id: number
  taskNo: string
  diyOrderNo: string
  templeCode: string
  masterCode: string
  status: string
  certificateUrls: string[]
  assignTime: string
  completeTime: string
  createTime: string
}

// ============ 寺院报表 ============
export interface BookingTrendPoint {
  date: string
  bookings: number
  revenue: number
}

export interface TempleRevenueStats {
  totalRevenue: number
  bookingCount: number
  avgBookingValue: number
  completedCount: number
}

export interface ServiceDistItem {
  serviceName: string
  count: number
  percentage: number
}

export interface MasterRankItem {
  masterCode: string
  masterName: string
  bookingCount: number
  revenue: number
}

export interface TempleReportResp {
  bookingTrend: BookingTrendPoint[]
  revenueStats: TempleRevenueStats
  serviceDistribution: ServiceDistItem[]
  masterRanking: MasterRankItem[]
}
