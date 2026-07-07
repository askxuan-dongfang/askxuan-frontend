// 预约接口
import client from './client';
import type { Booking, CreateBookingInput, PagedResult } from '../types';

// 创建预约
export function createBooking(data: CreateBookingInput): Promise<Booking> {
  return client.post('/bookings', data) as unknown as Promise<Booking>;
}

// 获取预约列表（后端返回分页对象 { total, list, page, size }）
export function getBookings(params?: { status?: string; page?: number; size?: number }): Promise<PagedResult<Booking>> {
  return client.get('/bookings', { params }) as unknown as Promise<PagedResult<Booking>>;
}

// 获取预约详情
export function getBooking(id: string): Promise<Booking> {
  return client.get(`/bookings/${id}`) as unknown as Promise<Booking>;
}
