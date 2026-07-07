// 服务接口（含服务项 + 功德金档位）
import client from './client';
import type { Service, MeritMoneyTier } from '../types';

export interface ServicesBundle {
  services: Service[];
  blessingServices: Service[];
  meritMoneyTiers: MeritMoneyTier[];
}

// 获取某寺院的服务集合（后端路由：/api/v1/temples/:id/services）
export function getServices(templeId: string): Promise<ServicesBundle> {
  return client.get(`/temples/${templeId}/services`) as unknown as Promise<ServicesBundle>;
}

// 获取单个服务详情（暂复用寺院服务列表，后端独立路由待实现）
export async function getService(templeId: string, id: string): Promise<Service | undefined> {
  const bundle = await getServices(templeId);
  return bundle.services.find((s) => s.id === id);
}
