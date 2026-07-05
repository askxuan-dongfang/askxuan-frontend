// 认证状态管理 - Pinia store
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import client from '@/api/client'
import { authApi } from '@/api/auth'
import type { AdminLoginParams, LoginResult, UserInfo } from '@/types'

export const useAuthStore = defineStore('auth', () => {
  // ===== State =====
  const token = ref<string>(localStorage.getItem('df_shop_admin_token') || '')
  const refreshToken = ref<string>(localStorage.getItem('df_shop_admin_refresh_token') || '')
  const userInfo = ref<UserInfo | null>(
    JSON.parse(localStorage.getItem('df_shop_admin_user') || 'null')
  )

  // ===== Getters =====
  const isLoggedIn = computed(() => !!token.value)
  const nickname = computed(() => userInfo.value?.nickname || '管理员')

  // ===== Actions =====
  /**
   * 商城运营登录
   * 调用真实接口 POST /auth/admin/login（账户 + 密码）
   * 后端不可达时直接抛错，禁止 Mock 兜底（安全要求）
   */
  async function login(params: AdminLoginParams): Promise<void> {
    const result = await authApi.adminLogin(params)
    setSession(result)
  }

  function setSession(result: LoginResult): void {
    token.value = result.accessToken
    refreshToken.value = result.refreshToken
    userInfo.value = result.userInfo
    localStorage.setItem('df_shop_admin_token', result.accessToken)
    localStorage.setItem('df_shop_admin_refresh_token', result.refreshToken)
    localStorage.setItem('df_shop_admin_user', JSON.stringify(result.userInfo))
  }

  /** 退出登录 */
  function logout(): void {
    token.value = ''
    refreshToken.value = ''
    userInfo.value = null
    localStorage.removeItem('df_shop_admin_token')
    localStorage.removeItem('df_shop_admin_refresh_token')
    localStorage.removeItem('df_shop_admin_user')
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
