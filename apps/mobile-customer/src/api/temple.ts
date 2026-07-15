// 寺院接口
import client from './client';
import type { Temple, PagedResult, TempleBookingService } from '../types';

// 获取寺院列表（后端返回 { total, list, page, size }）
export async function getTemples(params?: { sect?: string; type?: string; serviceCode?: string; page?: number; size?: number }): Promise<Temple[]> {
  const res = await client.get('/temples', { params }) as unknown as PagedResult<Temple> | Temple[];
  // 兼容分页对象和数组两种返回
  if (Array.isArray(res)) return res;
  return res?.list ?? [];
}

// 获取寺院详情
export function getTemple(id: string): Promise<Temple> {
  return client.get(`/temples/${id}`) as unknown as Promise<Temple>;
}

export async function getTempleServices(id: string): Promise<TempleBookingService[]> {
	const response = await client.get(`/temples/${id}/services`) as unknown as { list: TempleBookingService[] };
	return response.list ?? [];
}
