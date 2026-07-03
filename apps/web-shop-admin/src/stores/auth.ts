// 认证状态管理 - Pinia store
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import client from '@/api/client'
import { authApi } from '@/api/auth'
import type { AdminLoginParams, LoginResult, UserInfo } from '@/types'

export const useAuthStore = defineStore('auth', () => {
  // ===== State =====
  const token = ref<string>(localStorage.getItem('df_admin_token') || '')
  const refreshToken = ref<string>(localStorage.getItem('df_admin_refresh_token') || '')
  const userInfo = ref<UserInfo | null>(
    JSON.parse(localStorage.getItem('df_admin_user') || 'null')
  )

  // ===== Getters =====
  const isLoggedIn = computed(() => !!token.value)
  const nickname = computed(() => userInfo.value?.nickname || '管理员')

  // ===== Actions =====
  /**
   * 商城运营登录
   * 优先调用真实接口 POST /auth/admin/login（账户 + 密码）
   * 若后端不可达，回退到 Mock 校验（admin / 123456），便于本地开发预览
   */
  async function login(params: AdminLoginParams): Promise<void> {
    try {
      const result = await authApi.adminLogin(params)
      setSession(result)
    } catch (err) {
      // Mock 兜底：仅 admin / 123456 通过
      if (params.account === 'admin' && params.password === '123456') {
        const mock: LoginResult = {
          accessToken: 'mock-shop-admin-token',
          refreshToken: 'mock-shop-admin-refresh',
          expiresIn: 7200,
          userInfo: {
            userId: 1,
            nickname: '商城运营',
            avatar: '',
            mobile: '13800000000'
          }
        }
        setSession(mock)
        return
      }
      throw err
    }
  }

  function setSession(result: LoginResult): void {
    token.value = result.accessToken
    refreshToken.value = result.refreshToken
    userInfo.value = result.userInfo
    localStorage.setItem('df_admin_token', result.accessToken)
    localStorage.setItem('df_admin_refresh_token', result.refreshToken)
    localStorage.setItem('df_admin_user', JSON.stringify(result.userInfo))
  }

  /** 退出登录 */
  function logout(): void {
    token.value = ''
    refreshToken.value = ''
    userInfo.value = null
    localStorage.removeItem('df_admin_token')
    localStorage.removeItem('df_admin_refresh_token')
    localStorage.removeItem('df_admin_user')
  }

  return {
    token,
    refreshToken,
    userInfo,
    isLoggedIn,
    nickname,
    login,
    logout
  }
})

// 兼容 client.ts 在 401 时跳转
export { client }
