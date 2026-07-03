// 师傅接口
import client from './client';
import type { Master } from '../types';

// 获取师傅列表
export function getMasters(params?: { sect?: string; type?: string }): Promise<Master[]> {
  return client.get('/masters', { params }) as unknown as Promise<Master[]>;
}

// 获取师傅详情
export function getMaster(id: string): Promise<Master> {
  return client.get(`/masters/${id}`) as unknown as Promise<Master>;
}
