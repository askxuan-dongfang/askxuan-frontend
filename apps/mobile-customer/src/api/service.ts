// 服务接口（含服务项 + 功德金档位）
import client from './client';
import type { Service, MeritMoneyTier } from '../types';

export interface ServicesBundle {
  services: Service[];
  blessingServices: Service[];
  meritMoneyTiers: MeritMoneyTier[];
}

// 获取服务集合
export function getServices(): Promise<ServicesBundle> {
  return client.get('/services') as unknown as Promise<ServicesBundle>;
}

// 获取单个服务详情
export function getService(id: string): Promise<Service> {
  return client.get(`/services/${id}`) as unknown as Promise<Service>;
}
