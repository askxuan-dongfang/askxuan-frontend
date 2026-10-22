export interface WorkspaceItem { path: string; title: string; pending?: boolean }
export interface AdminWorkspace { title: string; icon: string; children: WorkspaceItem[] }

// Paths and permissions belong to the existing router. A pending item creates no route.
export const adminWorkspaces: AdminWorkspace[] = [
  { title: '工作台', icon: 'Odometer', children: [
    { path: '/dashboard', title: '平台总览' }, { path: '/commerce/dashboard', title: '现金商城工作台' }
  ] },
  { title: '机构与人员', icon: 'OfficeBuilding', children: [
    { path: '/temple/list', title: '寺院列表' }, { path: '/master/list', title: '法师列表' }, { path: '/user/list', title: '用户列表' }
  ] },
  { title: '服务与履约', icon: 'Van', children: [
    { path: '/services/overview', title: '服务与履约监管' },
    { path: '/services/temple-exceptions', title: '寺院异常监管' }
  ] },
  { title: '商城与 DIY', icon: 'Shop', children: [
    { path: '/commerce', title: '商城与 DIY 监管' }, { path: '/commerce/products', title: '商品管理' },
    { path: '/commerce/categories', title: '商品分类' }, { path: '/commerce/materials', title: 'DIY 材料' },
    { path: '/commerce/services', title: 'DIY 开光服务' }, { path: '/commerce/orders', title: '商城订单' },
    { path: '/commerce/diy-orders', title: 'DIY 订单' }, { path: '/commerce/logistics', title: '物流与运费' },
    { path: '/commerce/returns', title: '退货售后' }, { path: '/commerce/points-mall', title: '积分商城' }
  ] },
  { title: '审核与治理', icon: 'Checked', children: [
    { path: '/onboarding/review', title: '认证与入驻审核' }, { path: '/temple/review', title: '寺院初审与终审' },
    { path: '/master/review', title: '法师资质审核' }, { path: '/audit/comment', title: '评价审核' },
    { path: '/audit/design', title: '社区/短视频审核' }, { path: '/audit/report', title: '举报处理' },
    { path: '/settings/dict', title: '敏感词管理' }
  ] },
  { title: '财务中心', icon: 'Money', children: [
    { path: '/finance/overview', title: '财务概览' }, { path: '/finance/temple', title: '寺院结算' },
    { path: '/finance/master', title: '法师结算' }, { path: '/finance/reconcile', title: '提现审核与收支汇总' },
    { path: '/finance/payout-sandbox', title: '模拟打款测试' },
    { path: '/commerce/creator-rewards', title: '创作奖励与提现' }
  ] },
  { title: '运营中心', icon: 'Promotion', children: [
    { path: '/marketing/home-display', title: '首页分类展示' },
    { path: '/marketing/banner', title: '首页活动与广告' }, { path: '/marketing/activity', title: '活动管理' },
    { path: '/commerce/reports', title: '商城经营报表' },
    { path: '/marketing/growth', title: '成长体系' }, { path: '/marketing/rewards', title: '积分活动与奖品' },
    { path: '/marketing/coupon', title: '优惠券管理' }
  ] },
  { title: 'AI 中心', icon: 'Connection', children: [
    { path: '/ai/agent', title: '智能体编排' }, { path: '/ai/connections', title: '模型与连接' },
    { path: '/ai/knowledge', title: '知识中心' }, { path: '/ai/tools', title: '技能与工具' },
    { path: '/ai/debug', title: '调试工作台' }, { path: '/ai/evaluations', title: '质量评测' },
    { path: '/ai/releases', title: '版本与发布' }, { path: '/ai/runs', title: '运行监控' }
  ] },
  { title: '基础标准', icon: 'Collection', children: [
    { path: '/settings/taxonomy', title: '信仰与心愿标准' },
    { path: '/settings/directory-tags', title: '宗派信俗与资料选项' }, { path: '/settings/regions', title: '地区标签' },
    { path: '/settings/service-intentions', title: '心愿与服务关联' }
  ] },
  { title: '系统与权限', icon: 'Setting', children: [
    { path: '/settings/account', title: '管理账号' }, { path: '/settings/role', title: '角色权限' },
    { path: '/settings/log', title: '操作日志' }, { path: '/settings/backup', title: '数据备份' }
  ] }
]

export function activeWorkspacePath(path: string): string {
  if (path.startsWith('/ai/connections')) return '/ai/connections'
  if (path.startsWith('/temple/detail/')) return '/temple/list'
  if (path.startsWith('/master/detail/') || path === '/master/create') return '/master/list'
  if (path.startsWith('/user/detail/')) return '/user/list'
  if (path.startsWith('/settings/accounts/')) return '/settings/account'
  const shop = path.match(/^\/commerce\/(products|materials|services|orders|diy-orders|returns)\//)
  return shop ? `/commerce/${shop[1]}` : path
}

export function workspaceForPath(path: string) {
  const active = activeWorkspacePath(path)
  return adminWorkspaces.find(group => group.children.some(item => !item.pending && item.path === active))
}

export function workspaceItemForPath(path: string) {
  const active = activeWorkspacePath(path)
  return workspaceForPath(path)?.children.find(item => !item.pending && item.path === active)
}
