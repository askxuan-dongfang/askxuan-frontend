import type { AccountBinding, AccountIdentity } from '@/types'

export function accountScopeLabel(scope?: string): string {
  return ({ platform: '平台管理', temple: '寺院管理', master: '大师工作台', shop: '商城运营', applicant: '入驻申请' } as Record<string, string>)[scope || ''] || '权限范围待核对'
}

export function credentialLabel(identity: AccountIdentity): string {
  if (identity.activationStatus === 'pending' || identity.credentialState === 'pending_activation') return '待本人激活'
  if (identity.credentialState === 'verified_email' && identity.emailVerified) return '已验证邮箱'
  if (identity.credentialState === 'legacy_password') return '原有密码账号'
  return '认证资料待核对'
}

export function recoveryLabel(identity: AccountIdentity): string {
  if (identity.activationStatus === 'pending') return '由本人前往大师端激活，验证邀请邮箱并设置密码。'
  if (identity.canResetPassword && identity.emailVerified) return '本人可在登录页通过已验证邮箱找回密码。'
  return '未绑定已验证邮箱，当前不能通过邮箱找回；请由平台核验本人身份。'
}

export function bindingRoute(binding: Pick<AccountBinding, 'type' | 'id'>): string | null {
  const id = encodeURIComponent(binding.id)
  if (binding.type === 'temple') return `/temple/detail/${id}`
  if (binding.type === 'master') return `/master/detail/${id}`
  return null
}
