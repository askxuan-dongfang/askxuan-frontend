// axios 实例 - 统一网络层
// - baseURL 来自环境变量 EXPO_PUBLIC_API_BASE_URL
// - 请求拦截器注入 JWT（从 SecureStore 读取）
// - 响应拦截器解包 { code, message, data }，code !== 0 抛错
// - 401 清理 token 并跳转登录
import axios, {
  type AxiosInstance,
  type InternalAxiosRequestConfig,
  type AxiosResponse,
} from 'axios';
import { Platform } from 'react-native';
import { getToken, removeToken } from '../utils/storage';

// 延迟引入 router 避免循环依赖（运行时可用）
let routerReplace: ((path: string) => void) | null = null;
function getRouterReplace() {
  if (!routerReplace) {
    try {
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const { router } = require('expo-router');
      routerReplace = (path: string) => router.replace(path);
    } catch {
      routerReplace = null;
    }
  }
  return routerReplace;
}

const BASE_URL = process.env.EXPO_PUBLIC_API_BASE_URL || 'http://localhost:8080/api/v1';

const client: AxiosInstance = axios.create({
  baseURL: BASE_URL,
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// 请求拦截器：注入 JWT
client.interceptors.request.use(
  async (config: InternalAxiosRequestConfig) => {
    try {
      const token = await getToken();
      if (token) {
        config.headers.Authorization = `Bearer ${token}`;
      }
    } catch {
      // Web 平台或首次读取失败，忽略
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// 响应拦截器：解包统一格式 { code, message, data }
client.interceptors.response.use(
  (response: AxiosResponse) => {
    const body = response.data;
    if (body && typeof body === 'object' && 'code' in body) {
      // 后端约定：code === 0 表示成功
      if (body.code === 0) {
        return body.data; // 直接返回 data 字段
      }
      // 业务错误（含 40101 token 失效）
      if (body.code === 40101) {
        handleUnauthorized();
      }
      return Promise.reject(new Error(body?.message || '请求失败'));
    }
    // 非标准格式直接返回
    return body;
  },
  (error) => {
    const status = error.response?.status;
    if (status === 401) {
      handleUnauthorized();
    } else if (status === 500) {
      console.error('服务器错误：', error.response?.data);
    }
    return Promise.reject(error);
  }
);

// 401 处理：清理 token 并跳登录
let redirecting = false;
function handleUnauthorized() {
  if (redirecting) return;
  redirecting = true;
  removeToken().finally(() => {
    const replace = getRouterReplace();
    if (replace) {
      replace('/(tabs)/home');
    }
    redirecting = false;
  });
}

export default client;
