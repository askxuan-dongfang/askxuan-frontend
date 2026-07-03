import client from './client'
import type { Booking, BookingReview, BookingStatusLog, PageResult } from '@/types'

/** 预约列表（路由 /admin/bookings → booking-service，templeId 必传） */
export function listBookings(params: {
  templeId: string
  status?: string
  masterId?: string
  page?: number
  size?: number
}): Promise<PageResult<Booking>> {
  return client.get<PageResult<Booking>>('/admin/bookings', { params })
}

/** 预约详情 */
export function getBooking(id: string): Promise<Booking> {
  return client.get<Booking>(`/admin/bookings/${id}`)
}

/** 确认预约 */
export function confirmBooking(id: string, remark?: string): Promise<{ id: string; status: string }> {
  return client.put<{ id: string; status: string }>(`/admin/bookings/${id}/confirm`, { remark })
}

/** 取消预约 */
export function cancelBooking(id: string, remark?: string): Promise<{ id: string; status: string }> {
  return client.put<{ id: string; status: string }>(`/admin/bookings/${id}/cancel`, { remark })
}

/** 状态流转日志 */
export function getBookingStatusLog(id: string): Promise<{ list: BookingStatusLog[] }> {
  return client.get<{ list: BookingStatusLog[] }>(`/admin/bookings/${id}/status-log`)
}

/** 预约评价详情（booking-service 内置评价） */
export function getBookingReview(id: string): Promise<BookingReview> {
  return client.get<BookingReview>(`/admin/bookings/${id}/review`)
}

/** 回复预约评价 */
export function replyBookingReview(id: string, masterReply: string): Promise<BookingReview> {
  return client.put<BookingReview>(`/admin/bookings/${id}/review/reply`, { masterReply })
}
