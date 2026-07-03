// 寺院接口
import client from './client';
import type { Temple } from '../types';

// 获取寺院列表
export function getTemples(params?: { sect?: string; type?: string }): Promise<Temple[]> {
  return client.get('/temples', { params }) as unknown as Promise<Temple[]>;
}

// 获取寺院详情
export function getTemple(id: string): Promise<Temple> {
  return client.get(`/temples/${id}`) as unknown as Promise<Temple>;
}
