// 路由配置 - 23 条路由 + 守卫
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
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
    redirect: '/dashboard',
    children: [
      // 概览
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/DashboardView.vue'),
        meta: { title: '平台总览', icon: 'Odometer' }
      },
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
      // 营销管理
      {
        path: 'marketing/banner',
        name: 'MarketingBanner',
        component: () => import('@/views/marketing/MarketingBannerView.vue'),
        meta: { title: 'Banner 管理', parent: '营销管理' }
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
        path: 'settings/role',
        name: 'SettingsRole',
        component: () => import('@/views/settings/SettingsRoleView.vue'),
        meta: { title: '角色权限', parent: '系统设置' }
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

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 })
})

// 路由守卫：未登录跳 /login
router.beforeEach((to, _from, next) => {
  const auth = useAuthStore()
  document.title = `${to.meta.title || ''} · 问玄东方平台总管理台`
  if (to.meta.public) {
    if (to.name === 'Login' && auth.isLogin) {
      next('/dashboard')
    } else {
      next()
    }
    return
  }
  if (!auth.isLogin) {
    next({ path: '/login', query: { redirect: to.fullPath } })
  } else {
    next()
  }
})

export default router
