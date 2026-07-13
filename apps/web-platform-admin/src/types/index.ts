// 问玄东方 P05 平台总管理台 - 类型定义

// 统一响应格式 { code, message, data }
export interface ApiResponse<T = unknown> {
  code: number
  message: string
  data: T
}

// 通用分页响应
export interface PageResult<T> {
  total: number
  list: T[]
  page: number
  size: number
}

// 通用分页查询
export interface PageQuery {
  page?: number
  size?: number
}

// ========== Auth ==========
export interface UserInfo {
  userId: number
  nickname: string
  avatar: string
  mobile: string
}

export interface LoginResp {
  accessToken: string
  refreshToken: string
  expiresIn: number
  userInfo: UserInfo
  imToken?: string
}

export interface AdminAccount {
  id: number
  account: string
  name: string
  roleId: number
  roleName?: string
  templeId?: string
  masterId?: string
  shopId?: number
  status: string
  lastLoginTime?: string
  createTime: string
}

export interface Role {
  id: number
  name: string
  code: string
  description: string
  createTime: string
}

export interface Permission {
  id: number
  code: string
  name: string
  resource: string
  action: string
}

// ========== User ==========
export interface AdminUserItem {
  userId: number
  nickname: string
  mobile: string
  avatar: string
  region: string
  status: string
  totalOrders: number
  totalSpent: number
  createTime: string
}

export interface UserProfile {
  userId: number
  nickname: string
  avatar: string
  mobile: string
  gender: string
  birthday: string
  region: string
  bio: string
}

export interface AdminUserDetailResp {
  user: UserProfile
  preferenceTags: string[]
  totalOrders: number
  totalSpent: number
  lastActiveTime: string
  status: string
}

// ========== Temple ==========
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

export interface BeliefProfile {
  code: string
  name: string
  summary: string
  description: string
  coverImage: string
  sort: number
}

export interface TempleImage {
  id: number
  templeCode: string
  url: string
  type: string
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
  status: string
  createTime: string
}

export interface TempleDetail {
  temple: Temple
  images: TempleImage[]
  services: TempleService[]
}

export interface TempleAudit {
  id: number
  templeCode: string
  applicantName: string
  contactPhone: string
  certUrls: string[]
  status: string
  auditorId: number
  auditRemark: string
  createTime: string
}

// ========== Master ==========
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

export interface MasterAudit {
  id: number
  masterCode: string
  templeCode: string
  credentialUrls: string[]
  status: string
  auditorId: number
  auditRemark: string
  createTime: string
}

// ========== Audit ==========
export interface AuditQueue {
  id: number
  bizType: string
  bizId: string
  submitterId: string
  contentSnapshot: string
  status: string
  auditorId: string
  auditTime: string
  auditRemark: string
  createTime: string
}

export interface Report {
  id: number
  reporterId: string
  targetType: string
  targetId: string
  reason: string
  evidenceUrls: string
  status: string
  handlerId: string
  handleResult: string
  createTime: string
}

export interface SensitiveWord {
  id: number
  word: string
  category: string
  status: string
  createTime: string
}

export interface AuditStatistics {
  totalCount: number
  pendingCount: number
  approvedCount: number
  rejectedCount: number
  passRate: number
  avgAuditTime: number
}

// ========== Review ==========
export interface Review {
  id: number
  reviewNo: string
  userId: string
  targetType: string
  targetId: string
  rating: number
  content: string
  images: string
  status: string
  createTime: string
}

export interface ReviewReport {
  id: number
  reviewId: number
  reporterId: string
  reason: string
  status: string
  handleResult: string
  createTime: string
}

// ========== Finance ==========
export interface Settlement {
  id: number
  settlementNo: string
  settleType: string
  targetId: string
  targetName: string
  periodStart: string
  periodEnd: string
  orderCount: number
  totalAmount: number
  commissionRate: number
  commissionAmount: number
  settleAmount: number
  status: string
  createTime: string
}

export interface Withdrawal {
  id: number
  withdrawalNo: string
  applicantType: string
  applicantId: string
  amount: number
  bankCard: string
  status: string
  auditTime: string
  processTime: string
  createTime: string
}

export interface CommissionConfig {
  id: number
  bizType: string
  rate: number
  description: string
  updateTime: string
}

export interface FinanceOverview {
  totalIncome: number
  templeIncome: number
  masterIncome: number
  shopIncome: number
  commissionIncome: number
  pendingWithdraw: number
}

export interface FinanceReport {
  totalIncome: number
  totalSettlement: number
  totalWithdrawal: number
  orderCount: number
}

// ========== Marketing ==========
export interface Banner {
  id: number
  title: string
  imageUrl: string
  linkType: string
  linkValue: string
  sort: number
  status: string
  startTime: string
  endTime: string
  createdAt: string
}

export interface Activity {
  id: number
  name: string
  type: string
  startTime: string
  endTime: string
  config: string
  status: string
  createdAt: string
}

export interface Coupon {
  id: number
  couponNo: string
  name: string
  type: string
  value: number
  minAmount: number
  categoryId: string
  startTime: string
  endTime: string
  totalCount: number
  receivedCount: number
  status: string
  createdAt: string
}

// ========== Message ==========
export interface MessageTemplate {
  id: number
  code: string
  titleTemplate: string
  contentTemplate: string
  variables: string
  type: string
  createdAt: string
}

export interface SystemAnnouncement {
  id: number
  title: string
  content: string
  type: string
  targetAudience: string
  status: string
  publishTime: string
  createTime: string
}
