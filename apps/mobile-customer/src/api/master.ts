// 师傅接口
import client from './client';
import type { Master, PagedResult } from '../types';

// 获取师傅列表（后端返回 { total, list, page, size }）
export async function getMasters(params?: { sect?: string; type?: string; page?: number; size?: number }): Promise<Master[]> {
  const res = await client.get('/masters', { params }) as unknown as PagedResult<Master> | Master[];
  if (Array.isArray(res)) return res;
  return res?.list ?? [];
}

// 获取师傅详情
export function getMaster(id: string): Promise<Master> {
  return client.get(`/masters/${id}`) as unknown as Promise<Master>;
}
