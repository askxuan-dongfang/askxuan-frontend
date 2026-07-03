// 营销服务 API
import client from './client'
import type { Banner, Activity, Coupon, PageResult } from '@/types'

// ===== Banner =====
export function getBanners(params: { status?: string; page?: number; size?: number }) {
  return client.get<PageResult<Banner>>('/admin/marketing/banners', { params })
}
export function createBanner(params: {
  title: string
  imageUrl: string
  linkType: string
  linkValue: string
  sort?: number
  startTime: string
  endTime: string
}) {
  return client.post<{ id: number }>('/admin/marketing/banners', params)
}
export function updateBanner(id: number | string, params: Partial<Banner>) {
  return client.put<{ id: number }>(`/admin/marketing/banners/${id}`, params)
}

// ===== Activity =====
export function getActivities(params: { status?: string; type?: string; page?: number; size?: number }) {
  return client.get<PageResult<Activity>>('/admin/marketing/activities', { params })
}
export function createActivity(params: {
  name: string
  type: string
  startTime: string
  endTime: string
  config?: string
}) {
  return client.post<{ id: number }>('/admin/marketing/activities', params)
}
export function updateActivity(id: number | string, params: Partial<Activity>) {
  return client.put<{ id: number }>(`/admin/marketing/activities/${id}`, params)
}

// ===== Coupon =====
export function getCoupons(params: { status?: string; type?: string; page?: number; size?: number }) {
  return client.get<PageResult<Coupon>>('/admin/marketing/coupons', { params })
}
export function createCoupon(params: {
  name: string
  type: string
  value: number
  minAmount?: number
  categoryId?: string
  startTime: string
  endTime: string
  totalCount: number
}) {
  return client.post<{ id: number }>('/admin/marketing/coupons', params)
}
export function updateCoupon(id: number | string, params: Partial<Coupon>) {
  return client.put<{ id: number }>(`/admin/marketing/coupons/${id}`, params)
}
