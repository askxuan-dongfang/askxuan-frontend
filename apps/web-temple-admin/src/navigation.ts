export type TempleMenuItem = { path: string; label: string; permission?: string }
export type TempleMenuGroup = { id: string; label: string; icon: string; children: TempleMenuItem[] }

export const templeMenu: TempleMenuGroup[] = [
  { id: 'today', label: '今日工作台', icon: 'Odometer', children: [{ path: '/dashboard', label: '今日工作台' }] },
  { id: 'profile', label: '寺院资料', icon: 'OfficeBuilding', children: [
    { path: '/temple-info', label: '基本信息', permission: 'temple.profile.read' },
    { path: '/temple-gallery', label: '寺院图册', permission: 'temple.profile.read' }
  ] },
  { id: 'people', label: '人员管理', icon: 'User', children: [
    { path: '/masters', label: '法师档案', permission: 'temple.people.read' },
    { path: '/masters/accounts', label: '法师账号分配', permission: 'temple.team.manage' },
    { path: '/schedules', label: '排班日历', permission: 'temple.schedules.read' }
  ] },
  { id: 'services', label: '服务与履约', icon: 'Calendar', children: [
    { path: '/services', label: '服务配置', permission: 'temple.services.read' },
    { path: '/bookings', label: '预约订单', permission: 'temple.bookings.read' },
    { path: '/fulfillment', label: '履约记录', permission: 'temple.bookings.read' },
    { path: '/blessing-tasks', label: 'DIY 加持任务', permission: 'temple.blessings.read' },
    { path: '/exceptions', label: '异常跟进', permission: 'temple.exceptions.read' }
  ] },
  { id: 'engagement', label: '互动与运营', icon: 'ChatDotRound', children: [
    { path: '/reviews', label: '评价回复', permission: 'temple.reviews.read' },
    { path: '/growth', label: '优惠参与', permission: 'temple.growth.read' }
  ] },
  { id: 'finance', label: '财务与报表', icon: 'TrendCharts', children: [
    { path: '/wallet', label: '结算记录', permission: 'temple.finance.read' },
    { path: '/report', label: '经营统计', permission: 'temple.finance.read' }
  ] },
  { id: 'settings', label: '系统设置', icon: 'Setting', children: [
    { path: '/settings', label: '机构与账号' },
    { path: '/team', label: '岗位与成员', permission: 'temple.team.manage' }
  ] }
]

export function activeTempleMenu(path: string): string {
  if (path === '/masters/accounts') return path
  for (const prefix of ['/masters', '/services', '/bookings', '/blessing-tasks']) {
    if (path.startsWith(prefix + '/')) return prefix
  }
  return path
}
