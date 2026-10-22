import { ElMessage } from '@/i18n'
import { t as localizeTitle, subscribeLanguage } from '../../../../packages/localization/language'

import { t as uiText } from '../../../../packages/localization/language'
// 统一后台：保留 28 条平台业务路由，迁入 17 条商城业务路由。
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'

import { agentCenterRoutes } from './agentCenter'
import { commerceRoutes } from '@/commerce/routes'
import { canAccessRoute, defaultRoute } from './access'
import { useAuthStore } from '@/stores/auth'
import {StaleAuthorizationError} from '@/utils/adminAccess'

const Layout = () => import('@/layouts/DefaultLayout.vue')

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/LoginView.vue'),
    meta: { title: '登录', public: true }
  },
  {
    path: '/',
    component: Layout,
    redirect: () => defaultRoute(useAuthStore().roles, useAuthStore().access),
    // 统一入口按每个子路由授权，商城角色不继承平台权限。
    meta: { platformShell: true, roles: ['platform_super', 'platform_service', 'shop_admin'] },
    children: [
      {path:'access-denied',name:'AccessDenied',component:()=>import('@/views/AccessDeniedView.vue'),meta:{title:'功能权限',hidden:true,emptyAccess:true}},
      {path:'services/temple-exceptions',name:'TempleExceptions',component:()=>import('@/views/ExceptionsView.vue'),meta:{title:'寺院异常监管',roles:['platform_super'],superOnly:true}},
      {path:'services/overview',name:'ServiceOverview',component:()=>import('@/views/service/ServiceOverviewView.vue'),meta:{title:'服务与履约监管',roles:['platform_super'],superOnly:true}},
      {path:'finance/payout-sandbox',name:'PayoutSandbox',component:()=>import('@/views/finance/PayoutSandboxView.vue'),meta:{title:'模拟打款测试',roles:['platform_super'],superOnly:true}},
      {path:'marketing/home-display',name:'HomeDisplay',component:()=>import('@/views/settings/SettingsTaxonomyView.vue'),props:{mode:'display'},meta:{title:'首页分类展示',roles:['platform_super'],superOnly:true}},
      {path:'marketing/growth',name:'Growth',component:()=>import('@/views/GrowthView.vue'),meta:{title:'成长体系',parent:'运营管理',roles:['platform_super']}},
      {path:'onboarding/review',name:'onboarding-review',component:()=>import('@/views/OnboardingReviewView.vue'),meta:{title:'认证与入驻审核',roles:['platform_super']}},
      ...commerceRoutes,
 {path:'commerce/creator-rewards',name:'CreatorRewards',component:()=>import('@/commerce/views/CreatorRewardsView.vue'),meta:{title:'创作奖励与提现',parent:'商城与权益',roles:['platform_super'],hidden:false}},
 {path:'settings/service-intentions',name:'ServiceIntentions',component:()=>import('@/views/settings/ServiceIntentionsView.vue'),meta:{title:'心愿与服务关联',parent:'系统设置',roles:['platform_super']}},
      // 概览
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/DashboardView.vue'),
        meta: { title: '平台总览', icon: 'Odometer' }
      },
      {path:'commerce',name:'Commerce',component:()=>import('@/views/CommerceView.vue'),meta:{title:'商城运营中心',parent:'商城管理'}},
      // 寺院管理
      {
        path: 'temple/list',
        name: 'TempleList',
        component: () => import('@/views/temple/TempleListView.vue'),
        meta: { title: '寺院列表', parent: '寺院管理' }
      },
      {
        path: 'temple/detail/:id',
        name: 'TempleDetail',
        component: () => import('@/views/temple/TempleDetailView.vue'),
        meta: { title: '寺院详情', parent: '寺院管理', hidden: true }
      },
      {
        path: 'temple/review',
        name: 'TempleReview',
        component: () => import('@/views/temple/TempleReviewView.vue'),
        meta: { title: '寺院初审与终审', parent: '寺院管理' }
      },
      // 法师管理
      {
        path: 'master/list',
        name: 'MasterList',
        component: () => import('@/views/master/MasterListView.vue'),
        meta: { title: '法师列表', parent: '法师管理' }
      },
      {
        path: 'master/review',
        name: 'MasterReview',
        component: () => import('@/views/master/MasterReviewView.vue'),
        meta: { title: '法师资质审核', parent: '法师管理' }
      },
      {
        path: 'master/create',
        name: 'MasterCreate',
        component: () => import('@/views/master/MasterCreateView.vue'),
        meta: { title: '新增独立执业大师', parent: '法师管理' }
      },
      {
        path: 'master/detail/:id',
        name: 'MasterDetail',
        component: () => import('@/views/master/MasterDetailView.vue'),
        meta: { title: '法师详情', parent: '法师管理', hidden: true }
      },
      // 用户管理
      {
        path: 'user/list',
        name: 'UserList',
        component: () => import('@/views/user/UserListView.vue'),
        meta: { title: '用户列表', parent: '用户管理' }
      },
      {
        path: 'user/detail/:id',
        name: 'UserDetail',
        component: () => import('@/views/user/UserDetailView.vue'),
        meta: { title: '用户详情', parent: '用户管理', hidden: true }
      },
      // 内容审核
      {
        path: 'audit/comment',
        name: 'ContentComment',
        component: () => import('@/views/audit/ContentCommentView.vue'),
        meta: { title: '评价审核', parent: '内容审核' }
      },
      {
        path: 'audit/design',
        name: 'ContentDesign',
        component: () => import('@/views/audit/ContentDesignView.vue'),
        meta: { title: '素材审核', parent: '内容审核' }
      },
      {
        path: 'audit/report',
        name: 'ContentReport',
        component: () => import('@/views/audit/ContentReportView.vue'),
        meta: { title: '举报处理', parent: '内容审核' }
      },
      // 财务管理
      {
        path: 'finance/overview',
        name: 'FinanceOverview',
        component: () => import('@/views/finance/FinanceOverviewView.vue'),
        meta: { title: '财务概览', parent: '财务管理' }
      },
      {
        path: 'finance/temple',
        name: 'FinanceTemple',
        component: () => import('@/views/finance/FinanceTempleView.vue'),
        meta: { title: '寺院结算', parent: '财务管理' }
      },
      {
        path: 'finance/master',
        name: 'FinanceMaster',
        component: () => import('@/views/finance/FinanceMasterView.vue'),
        meta: { title: '法师结算', parent: '财务管理' }
      },
      {
        path: 'finance/reconcile',
        name: 'FinanceReconcile',
        component: () => import('@/views/finance/FinanceReconcileView.vue'),
        meta: { title: '提现审核与收支汇总', parent: '财务管理' }
      },
      {path:'marketing/rewards',name:'Rewards',component:()=>import('@/views/marketing/RewardsView.vue'),meta:{title:'积分活动与奖品',parent:'营销管理',roles:['platform_super']}},
      // 营销管理
      {
        path: 'marketing/banner',
        name: 'MarketingBanner',
        component: () => import('@/views/marketing/MarketingBannerView.vue'),
        meta: { title: '首页活动与广告', parent: '营销管理' }
      },
      {
        path: 'marketing/activity',
        name: 'MarketingActivity',
        component: () => import('@/views/marketing/MarketingActivityView.vue'),
        meta: { title: '活动管理', parent: '营销管理' }
      },
      {
        path: 'marketing/coupon',
        name: 'MarketingCoupon',
        component: () => import('@/views/marketing/MarketingCouponView.vue'),
        meta: { title: '优惠券管理', parent: '营销管理' }
      },
      // 系统设置
      {path:'settings/directory-tags',name:'SettingsDirectoryTags',component:()=>import('@/views/settings/SettingsDirectoryTagsView.vue'),meta:{title:'筛选标签',parent:'系统设置',roles:['platform_super']}},
      {path:'settings/regions',name:'SettingsRegions',component:()=>import('@/views/settings/SettingsRegionsView.vue'),meta:{title:'地区标签',parent:'系统设置',roles:['platform_super']}},
      {path:'ai',component:()=>import('@/views/ai/AgentCenterLayout.vue'),redirect:'/ai/agent',meta:{title:'问事智能体开发中心',roles:['platform_super']},children:agentCenterRoutes},
      {path:'ai/operations',name:'AgentOperations',redirect:to=>({path:'/ai/agent',query:to.query,hash:to.hash}),meta:{roles:['platform_super']}},
      {path:'settings/ai',name:'SettingsAi',redirect:to=>({path:'/ai/connections/models',query:to.query,hash:to.hash}),meta:{roles:['platform_super']}},
      {
        path: 'settings/taxonomy',
        name: 'SettingsTaxonomy',
        component: () => import('@/views/settings/SettingsTaxonomyView.vue'),
        props: {mode:'standard'},
 meta: { title: '信仰与心愿标准', parent: '系统设置',roles:['platform_super'],superOnly:true }
      },
      {
        path: 'settings/role',
        name: 'SettingsRole',
        component: () => import('@/views/settings/SettingsRoleView.vue'),
        meta: { title: '角色权限', parent: '系统设置' }
      },
      {
        path: 'settings/account',
        name: 'SettingsAccount',
        component: () => import('@/views/settings/SettingsAccountView.vue'),
        meta: { title: '账号管理', parent: '系统设置' }
      },
      {
        path: 'settings/dict',
        name: 'SettingsDict',
        component: () => import('@/views/settings/SettingsDictView.vue'),
        meta: { title: '敏感词管理', parent: '系统设置' }
      },
      {
        path: 'settings/log',
        name: 'SettingsLog',
        component: () => import('@/views/settings/SettingsLogView.vue'),
        meta: { title: '操作日志', parent: '系统设置' }
      },
      {
        path: 'settings/backup',
        name: 'SettingsBackup',
        component: () => import('@/views/settings/SettingsBackupView.vue'),
        meta: { title: '数据备份', parent: '系统设置' }
      }
    ]
  },
  { path: '/:pathMatch(.*)*', redirect: '/dashboard' }
]

// Preserve platform pages and their existing audience when adding the shop role.
for (const route of routes[1].children || []) {
  route.meta ||= {}
  route.meta.roles ||= ['platform_super', 'platform_service']
}

// The front-end catalog mirrors delegatable APIs; absent entries remain fixed-role only.
const routePermissions: Record<string, string[]> = {
 TempleList:['platform.temples.read'],TempleDetail:['platform.temples.read'],
 MasterList:['platform.masters.read'],MasterDetail:['platform.masters.read'],
 UserList:['platform.users.read'],UserDetail:['platform.users.read'],ContentReport:['platform.moderation.read'],
 FinanceOverview:['platform.finance.read'],FinanceTemple:['platform.finance.read'],FinanceMaster:['platform.finance.read'],FinanceReconcile:['platform.finance.read'],
 MarketingBanner:['platform.marketing.read'],MarketingActivity:['platform.marketing.read'],MarketingCoupon:['platform.marketing.read'],Rewards:['platform.marketing.read'],SettingsDict:['platform.moderation.read'],SettingsLog:['platform.operations.read'],
 ShopProductList:['platform.products.read'],ShopProductEdit:['platform.products.read','platform.products.write'],ShopCategoryManage:['platform.products.read'],
 ShopMaterialList:['platform.diy.read'],ShopMaterialEdit:['platform.diy.read','platform.diy.write'],ShopServiceList:['platform.diy.read'],ShopServiceEdit:['platform.diy.read','platform.diy.write'],
 ShopOrderList:['platform.orders.read'],ShopOrderDetail:['platform.orders.read'],ShopDiyOrderList:['platform.diy.read'],ShopDiyOrderDetail:['platform.diy.read'],ShopLogistics:['platform.logistics.read'],
 ShopReturnList:['platform.orders.read'],ShopReturnDetail:['platform.orders.read'],ShopReport:['platform.orders.read'],ShopPointsMall:['platform.points.read']
}
const superOnlyNames=['Growth','onboarding-review','CreatorRewards','ServiceIntentions','SettingsDirectoryTags','SettingsRegions','SettingsRole','SettingsAccount','SettingsBackup','SettingsTaxonomy','HomeDisplay','ServiceOverview','PayoutSandbox','TempleReview','MasterReview','MasterCreate','ContentComment','ContentDesign']
for (const route of routes[1].children || []) {
 route.meta ||= {}
 if(route.name && routePermissions[String(route.name)]) route.meta.permissions=routePermissions[String(route.name)]
 if(superOnlyNames.includes(String(route.name))) {route.meta.superOnly=true;route.meta.roles=['platform_super']}
}

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior: () => ({ top: 0 })
})

// Live bootstrap never trusts locally cached permissions. Backend version checks also protect each API.
router.beforeEach(async (to) => {
  const auth = useAuthStore()
  document.title = `${localizeTitle(to.meta.title || '')} · ${localizeTitle('问玄东方统一运营管理台')}`
  if (!auth.isLogin) return to.meta.public ? true : {path:'/login',query:{redirect:to.fullPath}}
  const capturedToken=auth.token
  try { await auth.ensureAccess() } catch (error) {
    if(error instanceof StaleAuthorizationError || auth.token!==capturedToken) return false
    auth.logout(); return to.meta.public ? true : {path:'/login'}
  }
  if (to.meta.public) return to.name==='Login' ? defaultRoute(auth.roles,auth.access) : true
  if (!canAccessRoute(to,auth.roles,auth.access)) {
    ElMessage.error(uiText('当前账号无此功能权限'))
    const landing=defaultRoute(auth.roles,auth.access)
    if(landing!==to.path && canAccessRoute(router.resolve(landing),auth.roles,auth.access)) return landing
    auth.logout();return {path:'/login',query:{denied:'1'}}
  }
  return true
})

export default router

subscribeLanguage(() => { document.title = `${localizeTitle(router.currentRoute.value.meta.title || '')} · ${localizeTitle('问玄东方统一运营管理台')}` })
