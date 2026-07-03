// 路由定义与守卫 - P04 商城管理台（17 条路由）
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes: RouteRecordRaw[] = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/LoginView.vue'),
    meta: { title: '登录', public: true }
  },
  {
    path: '/',
    component: () => import('@/layouts/DefaultLayout.vue'),
    redirect: '/dashboard',
    children: [
      // 1. 工作台
      {
        path: 'dashboard',
        name: 'Dashboard',
        component: () => import('@/views/DashboardView.vue'),
        meta: { title: '商城工作台' }
      },
      // 2. 商品列表
      {
        path: 'products',
        name: 'ProductList',
        component: () => import('@/views/ProductListView.vue'),
        meta: { title: '商品列表' }
      },
      // 3. 商品编辑（新建 / 编辑）
      {
        path: 'products/edit/:id?',
        name: 'ProductEdit',
        component: () => import('@/views/ProductEditView.vue'),
        meta: { title: '商品编辑' }
      },
      // 4. 分类管理
      {
        path: 'categories',
        name: 'CategoryManage',
        component: () => import('@/views/CategoryManageView.vue'),
        meta: { title: '分类管理' }
      },
      // 5. DIY 材料列表
      {
        path: 'materials',
        name: 'MaterialList',
        component: () => import('@/views/MaterialListView.vue'),
        meta: { title: '材料列表' }
      },
      // 6. 材料编辑
      {
        path: 'materials/edit/:id?',
        name: 'MaterialEdit',
        component: () => import('@/views/MaterialEditView.vue'),
        meta: { title: '材料编辑' }
      },
      // 7. 祈福服务列表
      {
        path: 'services',
        name: 'ServiceList',
        component: () => import('@/views/ServiceListView.vue'),
        meta: { title: '祈福服务列表' }
      },
      // 8. 祈福服务编辑
      {
        path: 'services/edit/:id?',
        name: 'ServiceEdit',
        component: () => import('@/views/ServiceEditView.vue'),
        meta: { title: '祈福服务编辑' }
      },
      // 9. 商城订单列表
      {
        path: 'orders',
        name: 'OrderList',
        component: () => import('@/views/OrderListView.vue'),
        meta: { title: '商城订单' }
      },
      // 10. 订单详情
      {
        path: 'orders/:id',
        name: 'OrderDetail',
        component: () => import('@/views/OrderDetailView.vue'),
        meta: { title: '订单详情' }
      },
      // 11. DIY 订单列表
      {
        path: 'diy-orders',
        name: 'DiyOrderList',
        component: () => import('@/views/DiyOrderListView.vue'),
        meta: { title: 'DIY 订单' }
      },
      // 12. DIY 订单详情
      {
        path: 'diy-orders/:id',
        name: 'DiyOrderDetail',
        component: () => import('@/views/DiyOrderDetailView.vue'),
        meta: { title: 'DIY 订单详情' }
      },
      // 13. 物流管理
      {
        path: 'logistics',
        name: 'Logistics',
        component: () => import('@/views/LogisticsView.vue'),
        meta: { title: '物流管理' }
      },
      // 14. 退货列表
      {
        path: 'returns',
        name: 'ReturnList',
        component: () => import('@/views/ReturnListView.vue'),
        meta: { title: '退货列表' }
      },
      // 15. 退货详情
      {
        path: 'returns/:id',
        name: 'ReturnDetail',
        component: () => import('@/views/ReturnDetailView.vue'),
        meta: { title: '退货详情' }
      },
      // 16. 商城报表
      {
        path: 'reports',
        name: 'Report',
        component: () => import('@/views/ReportView.vue'),
        meta: { title: '数据报表' }
      }
    ]
  },
  {
    path: '/:pathMatch(.*)*',
    redirect: '/dashboard'
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior: () => ({ top: 0 })
})

// 全局前置守卫：未登录跳转 /login
router.beforeEach((to, _from, next) => {
  const auth = useAuthStore()
  // 设置页面标题
  document.title = to.meta.title
    ? `${to.meta.title} · 商城管理台`
    : '问玄东方 · 商城管理台'

  if (to.meta.public) {
    // 已登录用户访问登录页则跳转工作台
    if (to.path === '/login' && auth.isLoggedIn) {
      next('/dashboard')
    } else {
      next()
    }
    return
  }

  if (!auth.isLoggedIn) {
    next({ path: '/login', query: { redirect: to.fullPath } })
    return
  }

  next()
})

export default router
