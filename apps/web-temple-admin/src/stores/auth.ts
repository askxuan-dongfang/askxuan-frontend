import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { adminLogin } from '@/api/auth'
import { jwtRoles, jwtClientId } from '@/utils/jwt'
import type { UserInfo } from '@/types'

const TOKEN_KEY = 'df_temple_admin_token'
const REFRESH_KEY = 'df_temple_admin_refresh_token'
const USER_KEY = 'df_temple_admin_user'
const TEMPLE_ID_KEY = 'df_temple_admin_temple_id'
const TEMPLE_NAME_KEY = 'df_temple_admin_temple_name'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string>(localStorage.getItem(TOKEN_KEY) || '')
  const refreshToken = ref<string>(localStorage.getItem(REFRESH_KEY) || '')
  const userInfo = ref<UserInfo | null>(loadUser())
  const templeId = ref<string>(localStorage.getItem(TEMPLE_ID_KEY) || '')
  const templeName = ref<string>(localStorage.getItem(TEMPLE_NAME_KEY) || '')

  const isLogin = computed(() => !!token.value)
  /** 从 JWT payload 解码出的角色列表（RBAC 守卫用） */
  const roles = computed(() => jwtRoles(token.value))
  /** 从 JWT payload 解码出的端标识 */
  const clientId = computed(() => jwtClientId(token.value))

  function loadUser(): UserInfo | null {
    try {
      const raw = localStorage.getItem(USER_KEY)
      return raw ? (JSON.parse(raw) as UserInfo) : null
    } catch {
      return null
    }
  }

  function persist() {
    if (token.value) localStorage.setItem(TOKEN_KEY, token.value)
    else localStorage.removeItem(TOKEN_KEY)
    if (refreshToken.value) localStorage.setItem(REFRESH_KEY, refreshToken.value)
    else localStorage.removeItem(REFRESH_KEY)
    if (userInfo.value) localStorage.setItem(USER_KEY, JSON.stringify(userInfo.value))
    else localStorage.removeItem(USER_KEY)
    localStorage.setItem(TEMPLE_ID_KEY, templeId.value)
    localStorage.setItem(TEMPLE_NAME_KEY, templeName.value)
  }

  async function login(account: string, password: string) {
    const resp = await adminLogin(account, password)
    token.value = resp.accessToken
    refreshToken.value = resp.refreshToken
    userInfo.value = resp.userInfo
    // 寺院管理员必须由后端返回 templeId（服务端隔离依据）；缺失说明账号未绑定寺院
    if (!resp.userInfo?.templeId) {
      throw new Error('账号未绑定寺院，请联系平台管理员')
    }
    templeId.value = resp.userInfo.templeId
    templeName.value = resp.userInfo.templeName || templeId.value
    persist()
    return resp
  }

  function setTemple(id: string, name: string) {
    templeId.value = id
    templeName.value = name
    persist()
  }

  function logout() {
    token.value = ''
    refreshToken.value = ''
    userInfo.value = null
    persist()
  }

  return {
    token,
    refreshToken,
    userInfo,
    templeId,
    templeName,
    isLogin,
    roles,
    clientId,
    login,
    logout,
    setTemple
  }
})
