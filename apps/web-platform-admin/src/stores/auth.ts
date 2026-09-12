import { subscribeAdminSession, startAdminSession } from '../../../../packages/admin-ui/session-expiry'
// 认证状态管理
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { adminLogin, type AdminLoginParams } from '@/api/auth'
import { jwtRoles, jwtClientId } from '@/utils/jwt'
import type { UserInfo } from '@/types'

const TOKEN_KEY = 'df_platform_admin_token'
const REFRESH_KEY = 'df_platform_admin_refresh_token'
const USER_KEY = 'df_platform_admin_user'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string>(localStorage.getItem(TOKEN_KEY) || '')
  const refreshToken = ref<string>(localStorage.getItem(REFRESH_KEY) || '')
  const userInfo = ref<UserInfo | null>(
    (() => {
      try {
        const raw = localStorage.getItem(USER_KEY)
        return raw ? (JSON.parse(raw) as UserInfo) : null
      } catch {
        return null
      }
    })()
  )

  const isLogin = computed(() => !!token.value)
  /** 从 JWT payload 解码出的角色列表（RBAC 守卫用） */
  const roles = computed(() => jwtRoles(token.value))
  /** 从 JWT payload 解码出的端标识 */
  const clientId = computed(() => jwtClientId(token.value))

  async function login(params: AdminLoginParams) {
    const res = await adminLogin(params)
    startAdminSession('df_platform_admin')
    token.value = res.accessToken
    refreshToken.value = res.refreshToken
    userInfo.value = res.userInfo
    localStorage.setItem(TOKEN_KEY, res.accessToken)
    localStorage.setItem(REFRESH_KEY, res.refreshToken)
    localStorage.setItem(USER_KEY, JSON.stringify(res.userInfo))
    return res
  }

  function logout() {
    localStorage.removeItem('df_platform_admin_session_id')
    token.value = ''
    refreshToken.value = ''
    userInfo.value = null
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(REFRESH_KEY)
    localStorage.removeItem(USER_KEY)
    // Old bookmarks must not restore a session after an explicit unified logout.
    for (const suffix of ['token', 'refresh_token', 'user', 'session_id']) localStorage.removeItem(`df_shop_admin_${suffix}`)
  }

  subscribeAdminSession('df_platform_admin', logout, () => {
    token.value = localStorage.getItem('df_platform_admin_token') || ''
    refreshToken.value = localStorage.getItem('df_platform_admin_refresh_token') || ''
  })

  return { token, refreshToken, userInfo, isLogin, roles, clientId, login, logout }
})
