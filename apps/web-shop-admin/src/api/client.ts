// 问玄东方 · shop 管理台 - 统一请求与失效会话处理
import axios, { type AxiosRequestConfig, type AxiosResponse, type InternalAxiosRequestConfig } from 'axios'
import { ElMessage } from 'element-plus'
import { ADMIN_SESSION_EXPIRED_EVENT, ADMIN_SESSION_REFRESHED_EVENT, AdminSessionExpiredError, createAdminSessionGuard, isAdminSessionExpired } from '../../../../packages/admin-ui/session-expiry'
import type { AdminRequestSession } from '../../../../packages/admin-ui/session-expiry'
import type { ApiResponse } from '@/types'

type SessionRequest = InternalAxiosRequestConfig & { _adminSession?: AdminRequestSession | null; _sessionRetried?: boolean }
const session = createAdminSessionGuard({
  prefix: 'df_shop_admin',
  baseUrl: import.meta.env.BASE_URL,
  storage: localStorage,
  location: window.location,
  invalidate: () => window.dispatchEvent(new CustomEvent(ADMIN_SESSION_EXPIRED_EVENT, { detail: { prefix: 'df_shop_admin' } })),
  refreshed: () => window.dispatchEvent(new CustomEvent(ADMIN_SESSION_REFRESHED_EVENT, { detail: { prefix: 'df_shop_admin' } })),
  refresh: async refreshToken => {
    // A separate, bounded request cannot re-enter these interceptors.
    const { data } = await axios.post<ApiResponse<{ accessToken: string; refreshToken?: string }>>('/api/v1/auth/refresh', { refreshToken }, {
      timeout: 10000,
      headers: { 'Content-Type': 'application/json', 'X-Client-Type': 'shop-admin', 'X-Client-Version': import.meta.env.VITE_APP_VERSION || '0.1.0' }
    })
    return data.code === 0 && data.data?.accessToken ? data.data : null
  }
})
const instance = axios.create({
  baseURL: '/api/v1',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json',
    'X-Client-Type': 'shop-admin',
    'X-Client-Version': import.meta.env.VITE_APP_VERSION || '0.1.0'
  }
})

instance.interceptors.request.use((config: SessionRequest) => {
  if (config._sessionRetried && session.isStale(config._adminSession)) throw new AdminSessionExpiredError()
  const snapshot = session.capture(config.url)
  config._adminSession = snapshot
  if (snapshot) config.headers.Authorization = `Bearer ${snapshot.token}`
  else config.headers.delete('Authorization')
  config.headers['X-Client-Type'] = 'shop-admin'
  config.headers['X-Client-Version'] = import.meta.env.VITE_APP_VERSION || '0.1.0'
  return config
})

instance.interceptors.response.use(
  async (response: AxiosResponse) => {
    const request = response.config as SessionRequest
    if (session.isStale(request._adminSession)) throw new AdminSessionExpiredError()
    const res = response.data as ApiResponse
    // Some services return raw JSON without the standard envelope.
    if (res === null || typeof res !== 'object' || !('code' in res)) return res as any
    if (res.code !== 0) {
      const recovery = await session.recover(request._adminSession, request.url, response.status, res.code, Boolean(request._sessionRetried))
      if (recovery.kind === 'retry') {
        request._sessionRetried = true
        return instance.request(request)
      }
      if (recovery.kind !== 'unhandled') throw new AdminSessionExpiredError()
      ElMessage.error(res.message || '请求失败')
      return Promise.reject(new Error(res.message || '请求失败'))
    }
    return res.data as any
  },
  async (error) => {
    if (isAdminSessionExpired(error)) return Promise.reject(error)
    const request = error.config as SessionRequest | undefined
    if (session.isStale(request?._adminSession)) return Promise.reject(new AdminSessionExpiredError())
    const recovery = await session.recover(request?._adminSession, request?.url, error.response?.status, error.response?.data?.code, Boolean(request?._sessionRetried))
    if (recovery.kind === 'retry' && request) {
      request._sessionRetried = true
      return instance.request(request)
    }
    if (recovery.kind !== 'unhandled') return Promise.reject(new AdminSessionExpiredError())
    ElMessage.error(error.response?.data?.message || error.message || '网络异常')
    return Promise.reject(error)
  }
)

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

export { isAdminSessionExpired }
