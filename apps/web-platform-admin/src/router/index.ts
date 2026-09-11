// 统一后台：保留 28 条平台业务路由，迁入 17 条商城业务路由。
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { ElMessage } from 'element-plus'
import { commerceRoutes } from '@/commerce/routes'
import { canAccessRoute, defaultRoute } from './access'
import { useAuthStore } from '@/stores/auth'

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
    redirect: () => defaultRoute(useAuthStore().roles),
    // 统一入口按每个子路由授权，商城角色不继承平台权限。
    meta: { roles: ['platform_super', 'platform_service', 'shop_admin'] },
    children: [
      ...commerceRoutes,
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
        meta: { title: '寺院审核', parent: '寺院管理' }
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
        meta: { title: '法师审核', parent: '法师管理' }
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
        meta: { title: '对账中心', parent: '财务管理' }
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
      {
        path: 'settings/taxonomy',
        name: 'SettingsTaxonomy',
        component: () => import('@/views/settings/SettingsTaxonomyView.vue'),
        meta: { title: '首页分类', parent: '系统设置' }
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
        meta: { title: '数据字典', parent: '系统设置' }
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

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior: () => ({ top: 0 })
})

// 路由守卫：未登录跳 /login
router.beforeEach((to, _from, next) => {
  const auth = useAuthStore()
  document.title = `${to.meta.title || ''} · 问玄东方平台总管理台`
  if (to.meta.public) {
    if (to.name === 'Login' && auth.isLogin) {
      next(defaultRoute(auth.roles))
    } else {
      next()
    }
    return
  }
  if (!auth.isLogin) {
    next({ path: '/login', query: { redirect: to.fullPath } })
    return
  }
  if (!canAccessRoute(to, auth.roles)) {
    ElMessage.error('当前账号无此功能权限')
    if (auth.roles.some(role => ['platform_super', 'platform_service', 'shop_admin'].includes(role))) {
      next(defaultRoute(auth.roles))
    } else {
      auth.logout()
      next({ path: '/login', query: { denied: '1' } })
    }
    return
  }
  next()
})

export default router
