// 问玄东方 · 商城管理台 - Axios 实例
// 统一处理 baseURL、token 注入、{ code, message, data } 响应格式
import axios, { type AxiosRequestConfig, type AxiosResponse, type InternalAxiosRequestConfig } from 'axios'
import { ElMessage } from 'element-plus'
import type { ApiResponse } from '@/types'

const instance = axios.create({
  baseURL: '/api/v1',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
    'X-Client-Type': 'shop-admin',
    'X-Client-Version': import.meta.env.VITE_APP_VERSION || '0.1.0'
  }
})

// 请求拦截器：注入 token
instance.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = localStorage.getItem('df_shop_admin_token')
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`
    }
    if (config.headers) {
      config.headers['X-Client-Type'] = 'shop-admin'
      config.headers['X-Client-Version'] = import.meta.env.VITE_APP_VERSION || '0.1.0'
    }
    return config
  },
  (error) => Promise.reject(error)
)

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = localStorage.getItem('df_shop_admin_refresh_token')
  if (!refreshToken) return null
  const { data } = await axios.post<ApiResponse<{ accessToken: string }>>(
    '/api/v1/auth/refresh',
    { refreshToken },
    {
      headers: {
        'Content-Type': 'application/json',
        'X-Client-Type': 'shop-admin',
        'X-Client-Version': import.meta.env.VITE_APP_VERSION || '0.1.0'
      }
    }
  )
  if (data.code !== 0 || !data.data?.accessToken) return null
  localStorage.setItem('df_shop_admin_token', data.data.accessToken)
  return data.data.accessToken
}

// 响应拦截器：统一处理 { code, message, data }，解包后直接返回 data 字段
instance.interceptors.response.use(
  (response: AxiosResponse<ApiResponse>) => {
    const res = response.data
    // 兼容 message-service 等返回原始 JSON（无 code 字段）的场景：直接透传
    if (res === null || typeof res !== 'object' || !('code' in res)) {
      return res as any
    }
    // 非 0 code 视为业务错误；40101 表示 JWT 失效，触发登出
    if (res.code !== 0) {
      if (res.code === 40101) {
        localStorage.removeItem('df_shop_admin_token')
        localStorage.removeItem('df_shop_admin_refresh_token')
        ElMessage.error('登录已过期，请重新登录')
        window.location.href = '/login'
        return Promise.reject(new Error(res.message || '未登录或登录已过期'))
      }
      ElMessage.error(res.message || '请求失败')
      return Promise.reject(new Error(res.message || 'Error'))
    }
    // 直接返回 data 字段，简化调用方
    return res.data as any
  },
  async (error) => {
    // HTTP 错误
    const originalRequest = error.config as (InternalAxiosRequestConfig & { _retry?: boolean }) | undefined
    if (error.response?.status === 401 && originalRequest && !originalRequest._retry) {
      originalRequest._retry = true
      try {
        const token = await refreshAccessToken()
        if (token) {
          originalRequest.headers.Authorization = `Bearer ${token}`
          return instance.request(originalRequest)
        }
      } catch {
        // fall through to logout
      }
    }
    if (error.response?.status === 401) {
      ElMessage.error('登录已过期，请重新登录')
      localStorage.removeItem('df_shop_admin_token')
      localStorage.removeItem('df_shop_admin_refresh_token')
      window.location.href = '/login'
    } else {
      ElMessage.error(error.response?.data?.message || error.message || '网络异常')
    }
    return Promise.reject(error)
  }
)

// 类型安全的封装：拦截器已解包，方法直接返回 Promise<T>
const client = {
  get<T = unknown>(url: string, config?: AxiosRequestConfig): Promise<T> {
    return instance.get(url, config) as unknown as Promise<T>
  },
  post<T = unknown>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<T> {
    return instance.post(url, data, config) as unknown as Promise<T>
  },
  put<T = unknown>(url: string, data?: unknown, config?: AxiosRequestConfig): Promise<T> {
    return instance.put(url, data, config) as unknown as Promise<T>
  },
  delete<T = unknown>(url: string, config?: AxiosRequestConfig): Promise<T> {
    return instance.delete(url, config) as unknown as Promise<T>
  }
}

export default client
