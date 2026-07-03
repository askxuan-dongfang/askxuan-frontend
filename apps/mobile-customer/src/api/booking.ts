// 预约接口
import client from './client';
import type { Booking, CreateBookingInput } from '../types';

// 创建预约
export function createBooking(data: CreateBookingInput): Promise<Booking> {
  return client.post('/bookings', data) as unknown as Promise<Booking>;
}

// 获取预约列表
export function getBookings(): Promise<Booking[]> {
  return client.get('/bookings') as unknown as Promise<Booking[]>;
}

// 获取预约详情
export function getBooking(id: string): Promise<Booking> {
  return client.get(`/bookings/${id}`) as unknown as Promise<Booking>;
}
