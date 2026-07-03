// 问玄东方 · 商城管理台 (P04) - 类型定义
// 与后端 .api 文件结构保持一致；字段命名 snake_case 来自后端 JSON

/* ============ 通用响应 ============ */
export interface ApiResponse<T = unknown> {
  code: number
  message: string
  data: T
}

/* ============ 分页 ============ */
export interface Page<T> {
  total: number
  list: T[]
  page: number
  size: number
}

/* ============ 认证 / 用户 ============ */
export interface AdminLoginParams {
  account: string
  password: string
}

export interface UserInfo {
  userId: number
  nickname: string
  avatar: string
  mobile: string
}

export interface LoginResult {
  accessToken: string
  refreshToken: string
  expiresIn: number
  userInfo: UserInfo
}

/* ============ 商品 ============ */
export type ProductStatus = 'draft' | 'on_shelf' | 'off_shelf'

export interface ProductSku {
  id: number
  productId: number
  specName: string
  specValue: string
  price: number
  stock: number
  skuNo: string
}

export interface ProductImage {
  id: number
  productId: number
  imageUrl: string
  sort: number
  type: string // main/detail
}

export interface Product {
  id: number
  productNo: string
  name: string
  categoryId: number
  categoryName?: string
  description: string
  mainImage: string
  status: ProductStatus
  price: number
  marketPrice: number
  stock: number
  tags: string
  freightTemplateId: number
  skus?: ProductSku[]
  images?: ProductImage[]
  createTime: string
  updateTime: string
}

export interface ProductCategory {
  id: number
  parentId: number
  name: string
  level: number
  sort: number
  children?: ProductCategory[]
}

/* ============ DIY 材料 ============ */
export type MaterialCategory =
  | 'main_bead'
  | 'spacer'
  | 'buddha_head'
  | 'pendant'
  | 'tassel'
  | 'three_way'
  | 'cord'

export interface Material {
  id: number
  name: string
  spec: string
  unitPrice: number
  unit: string
  category: MaterialCategory | string
  fiveElements?: string
  image: string
  stock: number
  status: string // on_shelf/off_shelf
}

/* ============ 祈福服务 ============ */
export interface BlessingService {
  id: number
  serviceCode: string
  serviceName: string
  templeCode: string
  templeName: string
  masterCode: string
  masterName: string
  price: number
  description: string
  status: string // on_shelf/off_shelf
}

/* ============ 商城订单 ============ */
export type OrderStatus =
  | 'pending_payment'
  | 'paid'
  | 'shipped'
  | 'completed'
  | 'cancelled'
  | 'in_return'

export interface ShopOrderItem {
  id?: number
  orderId?: number
  productId: number
  skuId?: number
  productName: string
  skuSpec?: string
  price: number
  quantity: number
  image?: string
}

export interface ShopOrderLogistics {
  id: number
  orderId: number
  expressCompany: string
  trackingNo: string
  shipTime: string
}

export interface ShopOrder {
  id: number
  orderNo: string
  userId: string
  totalAmount: number
  payAmount: number
  status: OrderStatus
  addressId: number
  note: string
  items?: ShopOrderItem[]
  logistics?: ShopOrderLogistics
  createTime: string
}

/* ============ 退货 ============ */
export type ReturnStatus =
  | 'pending_review'
  | 'approved'
  | 'return_shipping'
  | 'return_received'
  | 'refunding'
  | 'completed'
  | 'rejected'

export interface ReturnOrder {
  id: number
  returnNo: string
  orderId: number
  type: string // return/exchange
  reason: string
  status: ReturnStatus
  refundAmount: number
  createTime: string
}

/* ============ DIY 订单 ============ */
export interface DiyOrderItem {
  id: number
  orderId: number
  materialId: number
  materialName: string
  spec: string
  unitPrice: number
  quantity: number
  subtype: string
}

export interface BlessingTask {
  id: number
  taskNo: string
  diyOrderNo: string
  templeCode: string
  masterCode: string
  status: string
  certificateUrls?: string[]
  assignTime?: string
  completeTime?: string
}

export interface DiyOrder {
  id: number
  orderNo: string
  userId: string
  designId: number
  materialFee: number
  blessFee: number
  totalFee: number
  status: string
  addressId: number
  items?: DiyOrderItem[]
  blessingTask?: BlessingTask
  createTime: string
}

/* ============ 物流 ============ */
export interface ExpressCompany {
  id: number
  code: string
  name: string
  logoUrl: string
  customerService: string
  sort: number
  status: string // enabled/disabled
  createTime: string
  updateTime: string
}

export interface FreightTemplate {
  id: number
  name: string
  type: string // by_weight/by_piece
  freeShipping: number
  config: string
  status: string
  createTime: string
  updateTime: string
}

export interface TrackTrace {
  time: string
  desc: string
}

export interface TrackQueryResp {
  trackingNo: string
  expressCode: string
  expressName: string
  bizType: string
  bizNo: string
  status: string
  traces: TrackTrace[]
  lastSyncTime: string
}

/* ============ 财务报表 ============ */
export interface SalesTrendPoint {
  date: string
  sales: number
  orders: number
}

export interface TopProduct {
  productId: number
  productName: string
  sales: number
  orderCount: number
}

export interface ShopReport {
  totalSales: number
  totalOrders: number
  avgOrderValue: number
  refundRate: number
  salesTrend: SalesTrendPoint[]
  topProducts: TopProduct[]
}

/* ============ 仪表盘统计 ============ */
export interface DashboardStats {
  todayOrders: number
  todaySales: number
  pendingShip: number
  totalProducts: number
}
