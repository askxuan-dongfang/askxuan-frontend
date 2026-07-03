import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import DefaultLayout from '@/layouts/DefaultLayout.vue'

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'login',
    component: () => import('@/views/LoginView.vue'),
    meta: { title: '登录', public: true }
  },
  {
    path: '/',
    component: DefaultLayout,
    redirect: '/dashboard',
    children: [
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('@/views/DashboardView.vue'),
        meta: { title: '工作台' }
      },
      {
        path: 'temple-info',
        name: 'temple-info',
        component: () => import('@/views/TempleInfoView.vue'),
        meta: { title: '寺院信息' }
      },
      {
        path: 'masters',
        name: 'master-list',
        component: () => import('@/views/MasterListView.vue'),
        meta: { title: '法师管理' }
      },
      {
        path: 'masters/edit/:id?',
        name: 'master-edit',
        component: () => import('@/views/MasterEditView.vue'),
        meta: { title: '法师编辑' }
      },
      {
        path: 'services',
        name: 'service-list',
        component: () => import('@/views/ServiceListView.vue'),
        meta: { title: '服务管理' }
      },
      {
        path: 'services/edit/:id?',
        name: 'service-edit',
        component: () => import('@/views/ServiceEditView.vue'),
        meta: { title: '服务编辑' }
      },
      {
        path: 'bookings',
        name: 'booking-list',
        component: () => import('@/views/BookingListView.vue'),
        meta: { title: '预约管理' }
      },
      {
        path: 'bookings/:id',
        name: 'booking-detail',
        component: () => import('@/views/BookingDetailView.vue'),
        meta: { title: '预约详情' }
      },
      {
        path: 'reviews',
        name: 'review-list',
        component: () => import('@/views/ReviewListView.vue'),
        meta: { title: '评价管理' }
      },
      {
        path: 'report',
        name: 'report',
        component: () => import('@/views/ReportView.vue'),
        meta: { title: '数据报表' }
      },
      {
        path: 'settings',
        name: 'settings',
        component: () => import('@/views/SettingsView.vue'),
        meta: { title: '系统设置' }
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

router.beforeEach((to) => {
  const auth = useAuthStore()
  // 设置标题
  if (to.meta.title) document.title = `${to.meta.title} · 寺院管理台`
  // 公开路由放行
  if (to.meta.public) {
    if (auth.isLogin && to.name === 'login') return { path: '/dashboard' }
    return true
  }
  // 未登录跳登录
  if (!auth.isLogin) {
    return { path: '/login', query: { redirect: to.fullPath } }
  }
  return true
})

export default router
