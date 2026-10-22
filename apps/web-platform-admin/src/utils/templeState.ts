import type { Temple } from '@/types'

export function templeAuthLabel(value: Temple['authStatus']) {
  return value === 'certified' ? '已认证' : value === 'pending' ? '待审核' : '历史认证待核对'
}

export function canShelfTemple(temple: Temple): boolean {
  return temple.authStatus === 'certified' && temple.platformStatus === 'normal'
}

export function templeStateAvailable(temple: Temple): boolean {
  return Number.isSafeInteger(temple.stateVersion) && (temple.stateVersion ?? -1) >= 0 && Boolean(temple.platformStatus && temple.shelfStatus && temple.authStatus)
}
