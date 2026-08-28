// 认证接口
import client from './client';
import type { LoginResult } from '../types';

// 手机号 + 验证码登录
export function login(phone: string, code: string): Promise<LoginResult> {
  return client.post('/auth/login', { phone, code }) as unknown as Promise<LoginResult>;
}

// 备用客户端契约：演示注册不校验真实短信验证码。
export function register(mobile: string, nickname?: string): Promise<{ userId: number; mobile: string; nickname: string; imReady: boolean }> {
  return client.post('/users/register', { mobile, nickname }) as unknown as Promise<{ userId: number; mobile: string; nickname: string; imReady: boolean }>;
}

// 登出（清理本地态由 store 处理）
export function logout(): Promise<void> {
  return Promise.resolve();
}

// 刷新 token
export function refresh(): Promise<{ accessToken: string; expiresIn: number }> {
  return client.post('/auth/refresh') as unknown as Promise<{ accessToken: string; expiresIn: number }>;
}
