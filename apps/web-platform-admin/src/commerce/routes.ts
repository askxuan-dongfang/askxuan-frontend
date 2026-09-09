import type { RouteRecordRaw } from 'vue-router'

// Full migration of the former shop console; every legacy business route has a destination.
export const commerceRoutes: RouteRecordRaw[] = [
  { path: 'commerce/points-mall', name: 'ShopPointsMall', component: () => import('./views/PointsMallView.vue'), meta: { title: '积分商城', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/dashboard', name: 'ShopDashboard', component: () => import('./views/DashboardView.vue'), meta: { title: '商城工作台', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/products', name: 'ShopProductList', component: () => import('./views/ProductListView.vue'), meta: { title: '商品列表', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/products/edit/:id?', name: 'ShopProductEdit', component: () => import('./views/ProductEditView.vue'), meta: { title: '商品编辑', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: true } },
  { path: 'commerce/categories', name: 'ShopCategoryManage', component: () => import('./views/CategoryManageView.vue'), meta: { title: '分类管理', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/materials', name: 'ShopMaterialList', component: () => import('./views/MaterialListView.vue'), meta: { title: '材料列表', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/materials/edit/:id?', name: 'ShopMaterialEdit', component: () => import('./views/MaterialEditView.vue'), meta: { title: '材料编辑', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: true } },
  { path: 'commerce/services', name: 'ShopServiceList', component: () => import('./views/ServiceListView.vue'), meta: { title: '祈福服务列表', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/services/edit/:id?', name: 'ShopServiceEdit', component: () => import('./views/ServiceEditView.vue'), meta: { title: '祈福服务编辑', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: true } },
  { path: 'commerce/orders', name: 'ShopOrderList', component: () => import('./views/OrderListView.vue'), meta: { title: '商城订单', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/orders/:id', name: 'ShopOrderDetail', component: () => import('./views/OrderDetailView.vue'), meta: { title: '订单详情', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: true } },
  { path: 'commerce/diy-orders', name: 'ShopDiyOrderList', component: () => import('./views/DiyOrderListView.vue'), meta: { title: 'DIY 订单', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/diy-orders/:id', name: 'ShopDiyOrderDetail', component: () => import('./views/DiyOrderDetailView.vue'), meta: { title: 'DIY 订单详情', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: true } },
  { path: 'commerce/logistics', name: 'ShopLogistics', component: () => import('./views/LogisticsView.vue'), meta: { title: '物流管理', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/returns', name: 'ShopReturnList', component: () => import('./views/ReturnListView.vue'), meta: { title: '退货列表', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
  { path: 'commerce/returns/:id', name: 'ShopReturnDetail', component: () => import('./views/ReturnDetailView.vue'), meta: { title: '退货详情', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: true } },
  { path: 'commerce/reports', name: 'ShopReport', component: () => import('./views/ReportView.vue'), meta: { title: '数据报表', parent: '商城与权益', roles: ['shop_admin', 'platform_super'], hidden: false } },
]
