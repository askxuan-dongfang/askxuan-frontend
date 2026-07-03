// 认证接口
import client from './client';
import type { LoginResult } from '../types';

// 手机号 + 验证码登录
export function login(phone: string, code: string): Promise<LoginResult> {
  return client.post('/auth/login', { phone, code }) as unknown as Promise<LoginResult>;
}

// 登出（清理本地态由 store 处理）
export function logout(): Promise<void> {
  return Promise.resolve();
}

// 刷新 token（后端暂未实现，占位）
export function refresh(): Promise<{ token: string }> {
  return client.post('/auth/refresh') as unknown as Promise<{ token: string }>;
}
