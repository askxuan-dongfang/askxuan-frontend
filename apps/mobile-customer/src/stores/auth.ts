// 认证状态 - Zustand 管理客户端登录态
import { create } from 'zustand';
import type { User } from '../types';
import { getToken, setToken, removeToken, setUserCache, removeUserCache } from '../utils/storage';

interface AuthState {
  token: string | null;
  user: User | null;
  isAuthenticated: boolean;
  // 初始化：从安全存储恢复登录态
  hydrate: () => Promise<void>;
  // 登录成功后写入
  login: (token: string, user: User) => Promise<void>;
  // 登出
  logout: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  token: null,
  user: null,
  isAuthenticated: false,

  hydrate: async () => {
    const token = await getToken();
    set({ token, isAuthenticated: !!token });
  },

  login: async (token, user) => {
    await setToken(token);
    await setUserCache(JSON.stringify(user));
    set({ token, user, isAuthenticated: true });
  },

  logout: async () => {
    await removeToken();
    await removeUserCache();
    set({ token: null, user: null, isAuthenticated: false });
  },
}));
