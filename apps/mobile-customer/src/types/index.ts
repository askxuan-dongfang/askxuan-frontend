// 全局类型定义 - 与后端统一数据字典对齐

// 统一响应格式 { code, message, data }
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

// 寺院
export interface Temple {
  id: string;
  name: string;
  region: string; // 地区，如 "浙江杭州"
  type: string; // 寺院类型：汉传佛教/藏传佛教/道教
  sect: string; // 宗派：禅宗/净土宗/全真派等
  status: string; // 状态：正常/待审核
  address: string;
  coverImage: string;
  rating: number;
  description: string;
}

// 师傅/法师
export interface Master {
  id: string;
  dharmaName: string; // 法号
  layName: string; // 俗名
  templeId: string;
  templeName: string;
  position: string; // 职位：住持/监院/首座等
  sect: string; // 宗派
  type: string; // 类型：佛教/道教
  authStatus: string; // 认证状态
  specialties: string[]; // 擅长领域
  avatar: string;
  rating: number;
  isOnline?: boolean; // 在线状态（前端扩展，后端可选）
  startPrice?: number; // 起步价（前端扩展，后端可选）
}

// 服务项
export interface Service {
  id: string;
  name: string;
  category: string;
  description: string;
  price: number;
  duration: string;
  image?: string;
}

// 功德金档位
export interface MeritMoneyTier {
  tier: string;
  amount: number; // -1 表示自定义
  description: string;
}

// 预约订单
export interface Booking {
  id: string;
  userId: string;
  templeId: string;
  templeName: string;
  masterId: string;
  masterName: string;
  serviceId: string;
  serviceName: string;
  bookingDate: string;
  timeSlot: string;
  meritMoney: number;
  meritMoneyTier: string;
  status: string; // 待确认/已确认/进行中/已完成/已取消
  createdAt: string;
  note: string;
}

// 创建预约的入参
export interface CreateBookingInput {
  templeId: string;
  templeName: string;
  masterId: string;
  masterName: string;
  serviceId: string;
  serviceName: string;
  bookingDate: string;
  timeSlot: string;
  meritMoney: number;
  meritMoneyTier: string;
  note?: string;
}

// 用户
export interface User {
  userId: string;
  phone: string;
  nickname: string;
  avatar: string;
  createdAt: string;
}

// 登录响应
export interface LoginResult {
  token: string;
  user: User;
}

// 轮播图
export interface Banner {
  id: string;
  title: string;
  image?: string;
  gradient: [string, string]; // 渐变占位色
}
