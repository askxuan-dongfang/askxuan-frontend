import { subscribeAdminSession, startAdminSession } from '../../../../packages/admin-ui/session-expiry'
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import client from '@/api/client'
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

  const permissions = ref<string[]>([])
  const workspaceVerified = ref(false)
  let verifiedToken = ''
  let pendingWorkspace: Promise<void> | null = null
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
    if (templeId.value) localStorage.setItem(TEMPLE_ID_KEY, templeId.value)
    else localStorage.removeItem(TEMPLE_ID_KEY)
    if (templeName.value) localStorage.setItem(TEMPLE_NAME_KEY, templeName.value)
    else localStorage.removeItem(TEMPLE_NAME_KEY)
  }

  async function login(account: string, password: string, proof:{captchaId:string;captchaCode:string}) {
    const resp = await adminLogin(account, password, proof)
    // 寺院管理员必须由后端返回 templeId（服务端隔离依据）；缺失说明账号未绑定寺院
    if (!resp.userInfo?.templeId && !jwtRoles(resp.accessToken).includes('temple_applicant')) {
      throw new Error('账号未绑定寺院，请联系平台管理员')
    }
    startAdminSession('df_temple_admin')
    token.value = resp.accessToken
    refreshToken.value = resp.refreshToken
    userInfo.value = resp.userInfo
    templeId.value = resp.userInfo.templeId || ''
    templeName.value = resp.userInfo.templeName || templeId.value
    persist()
    return resp
  }

  function can(permission: string) {
    return workspaceVerified.value && (roles.value.includes('temple_admin') || roles.value.includes('platform_super') || permissions.value.includes(permission))
  }

  async function syncWorkspace() {
    if (workspaceVerified.value && verifiedToken === token.value) return
    if (pendingWorkspace) return pendingWorkspace
    workspaceVerified.value = false
    pendingWorkspace = (async () => {
      const access = await client.get<{ templeCode: string; templeName: string; permissions: string[] }>('/auth/access')
      if (!access.templeCode) throw new Error('账号未绑定寺院，请联系平台管理员')
      templeId.value = access.templeCode
      templeName.value = access.templeName || access.templeCode
      permissions.value = access.permissions || []
      verifiedToken = token.value
      workspaceVerified.value = true
      persist()
    })().finally(() => { pendingWorkspace = null })
    return pendingWorkspace
  }

  function logout() {
    workspaceVerified.value = false
    permissions.value = []
    verifiedToken = ''
    const previous=token.value;
    if(previous)void fetch('/api/v1/auth/logout',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+previous},body:JSON.stringify({accessToken:previous})}).catch(()=>{});

    localStorage.removeItem('df_temple_admin_session_id')
    token.value = ''
    refreshToken.value = ''
    userInfo.value = null
    templeId.value = ''
    templeName.value = ''
    persist()
  }

  subscribeAdminSession('df_temple_admin', logout, () => {
    workspaceVerified.value = false
    permissions.value = []
    verifiedToken = ''
    token.value = localStorage.getItem('df_temple_admin_token') || ''
    refreshToken.value = localStorage.getItem('df_temple_admin_refresh_token') || ''
    // Refresh permissions for the visible page, even when the route has not changed.
    void syncWorkspace().catch(logout)
  })

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
    syncWorkspace,
    workspaceVerified,
    permissions,
    can
  }
})
