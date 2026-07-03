import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { adminLogin } from '@/api/auth'
import type { UserInfo } from '@/types'

const TOKEN_KEY = 'df_admin_token'
const REFRESH_KEY = 'df_admin_refresh_token'
const USER_KEY = 'df_admin_user'
const TEMPLE_ID_KEY = 'df_admin_temple_id'
const TEMPLE_NAME_KEY = 'df_admin_temple_name'

// Mock 账号 lingyin_admin 对应灵隐寺，默认 templeId 兜底
const DEFAULT_TEMPLE_ID = 'T001'
const DEFAULT_TEMPLE_NAME = '灵隐寺'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string>(localStorage.getItem(TOKEN_KEY) || '')
  const refreshToken = ref<string>(localStorage.getItem(REFRESH_KEY) || '')
  const userInfo = ref<UserInfo | null>(loadUser())
  const templeId = ref<string>(localStorage.getItem(TEMPLE_ID_KEY) || DEFAULT_TEMPLE_ID)
  const templeName = ref<string>(localStorage.getItem(TEMPLE_NAME_KEY) || DEFAULT_TEMPLE_NAME)

  const isLogin = computed(() => !!token.value)

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
    // 登录响应若携带 templeId 则采用，否则沿用本地配置
    if (resp.userInfo?.templeId) {
      templeId.value = resp.userInfo.templeId
      templeName.value = resp.userInfo.templeName || templeName.value
    }
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
    login,
    logout,
    setTemple
  }
})
