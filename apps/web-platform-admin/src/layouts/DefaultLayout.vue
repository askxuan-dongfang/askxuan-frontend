<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { canAccessRoute, defaultRoute } from '@/router/access'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const logoUrl = `${import.meta.env.BASE_URL}logos/logo-platform.png`
const collapsed = ref(false)
const mobile = ref(false)
const drawerOpen = ref(false)
let mobileQuery: MediaQueryList | undefined

const allMenuGroups = [
  {title:'商城与权益',icon:'Shop',children:[
    {path:'/commerce',title:'商城运营总览'},
    {path:'/commerce/dashboard',title:'商城工作台'},
    {path:'/commerce/products',title:'商品管理'},
    {path:'/commerce/categories',title:'商品分类'},
    {path:'/commerce/points-mall',title:'积分商城'},
    {path:'/commerce/reports',title:'经营报表'}
  ]},
  {title:'DIY 与加持服务',icon:'MagicStick',children:[
    {path:'/commerce/materials',title:'DIY 材料'},
    {path:'/commerce/services',title:'加持服务'},
    {path:'/commerce/diy-orders',title:'DIY 订单'}
  ]},
  {title:'履约与售后',icon:'Van',children:[
    {path:'/commerce/orders',title:'商城订单'},
    {path:'/commerce/logistics',title:'物流与运费'},
    {path:'/commerce/returns',title:'退货售后'}
  ]},
  {
    title: '机构与人员',
    icon: 'OfficeBuilding',
    children: [
      { path: '/temple/list', title: '寺院列表' },
      { path: '/master/list', title: '法师列表' },
      { path: '/user/list', title: '用户列表' },
      { path: '/settings/account', title: '管理账号' }
    ]
  },
  {
    title: '审核中心',
    icon: 'Checked',
    children: [
      { path: '/temple/review', title: '寺院审核' },
      { path: '/master/review', title: '法师审核' },
      { path: '/audit/comment', title: '评价审核' },
      { path: '/audit/design', title: '社区/短视频审核' },
      { path: '/audit/report', title: '举报处理' }
    ]
  },
  {
    title: '财务中心',
    icon: 'Money',
    children: [
      { path: '/finance/overview', title: '财务概览' },
      { path: '/finance/temple', title: '寺院结算' },
      { path: '/finance/master', title: '法师结算' },
      { path: '/finance/reconcile', title: '对账中心' }
    ]
  },
  {
    title: '增长运营',
    icon: 'Promotion',
    children: [
      { path: '/marketing/banner', title: '首页活动与广告' },
      { path: '/marketing/activity', title: '活动管理' },
      { path: '/marketing/rewards', title: '积分活动与奖品' },
      { path: '/marketing/coupon', title: '优惠券管理' },
      { path: '/settings/taxonomy', title: '首页分类' }
    ]
  },
  {
    title: '系统治理',
    icon: 'Setting',
    children: [
      { path: '/settings/role', title: '角色权限' },
      { path: '/settings/dict', title: '数据字典' },
      { path: '/settings/log', title: '操作日志' },
      { path: '/settings/backup', title: '数据备份' }
    ]
  }
]

const menuGroups = computed(() => allMenuGroups.map(group => ({ ...group, children: group.children.filter(item => canAccessRoute(router.resolve(item.path), auth.roles)) })).filter(group => group.children.length))
const homePath = computed(() => defaultRoute(auth.roles))

const activeMenu = computed(() => {
  const path = route.path
  if (path.startsWith('/temple/detail/')) return '/temple/list'
  if (path.startsWith('/master/detail/') || path === '/master/create') return '/master/list'
  if (path.startsWith('/user/detail/')) return '/user/list'
  const shop = path.match(/^\/commerce\/(products|materials|services|orders|diy-orders|returns)\//)
  if (shop) return `/commerce/${shop[1]}`
  return path
})
const avatarText = computed(() => (auth.userInfo?.nickname || '管').slice(0, 1))
const pageTitle = computed(() => (route.meta.title as string) || '平台管理台')
const pageParent = computed(() => (route.meta.parent as string) || '平台管理台')

function syncViewport(event?: MediaQueryListEvent) {
  mobile.value = event ? event.matches : Boolean(mobileQuery?.matches)
  if (!mobile.value) drawerOpen.value = false
}

function toggleNavigation() {
  if (mobile.value) drawerOpen.value = !drawerOpen.value
  else collapsed.value = !collapsed.value
}

async function onCommand(cmd: string) {
  if (cmd === 'logout') {
    try {
      await ElMessageBox.confirm('确定要退出登录吗？', '退出登录', {
        confirmButtonText: '退出',
        cancelButtonText: '取消',
        type: 'warning'
      })
      auth.logout()
      await router.push('/login')
    } catch {
      // 用户取消。
    }
  } else if (cmd === 'dashboard') {
    await router.push(homePath.value)
  }
}

watch(() => route.fullPath, () => { drawerOpen.value = false })

onMounted(() => {
  mobileQuery = window.matchMedia('(max-width: 991px)')
  syncViewport()
  mobileQuery.addEventListener('change', syncViewport)
})

onBeforeUnmount(() => mobileQuery?.removeEventListener('change', syncViewport))
</script>

<template>
  <div
    class="ax-admin-shell"
    :class="{ 'is-collapsed': collapsed && !mobile, 'is-drawer-open': drawerOpen }"
  >
    <button class="ax-admin-overlay" type="button" aria-label="关闭导航" @click="drawerOpen = false"></button>

    <aside class="ax-admin-sidebar" aria-label="平台管理台主导航">
      <div class="ax-admin-logo">
        <img class="ax-admin-logo__image" :src="logoUrl" alt="" />
        <div class="ax-admin-logo__copy">
          <div class="ax-admin-logo__title">问玄东方</div>
          <div class="ax-admin-logo__subtitle">统一运营管理台</div>
        </div>
      </div>

      <el-menu
        :default-active="activeMenu"
        :collapse="collapsed && !mobile"
        :collapse-transition="false"
        background-color="transparent"
        text-color="#C5B097"
        active-text-color="#F5E0D6"
        router
        unique-opened
        class="ax-admin-menu"
      >
        <el-menu-item :index="homePath">
          <el-icon><Odometer /></el-icon>
          <template #title>{{ homePath === '/dashboard' ? '平台总览' : '今日工作台' }}</template>
        </el-menu-item>

        <el-sub-menu v-for="group in menuGroups" :key="group.title" :index="group.title">
          <template #title>
            <el-icon><component :is="group.icon" /></el-icon>
            <span>{{ group.title }}</span>
          </template>
          <el-menu-item v-for="item in group.children" :key="item.path" :index="item.path">
            {{ item.title }}
          </el-menu-item>
        </el-sub-menu>
      </el-menu>

      <div class="ax-admin-version">统一运营管理台</div>
    </aside>

    <section class="ax-admin-content">
      <header class="ax-admin-header">
        <div class="ax-admin-header__left">
          <button
            class="ax-admin-nav-toggle"
            type="button"
            aria-label="切换主导航"
            :aria-expanded="mobile ? drawerOpen : !collapsed"
            @click="toggleNavigation"
          >
            <el-icon :size="20">
              <Menu v-if="mobile" />
              <Expand v-else-if="collapsed" />
              <Fold v-else />
            </el-icon>
          </button>
          <div>
            <div class="ax-admin-header__eyebrow">{{ pageParent }}</div>
            <div class="ax-admin-header__title">{{ pageTitle }}</div>
          </div>
        </div>

        <div class="ax-admin-header__right">
          <el-dropdown @command="onCommand">
            <button class="ax-admin-user" type="button">
              <el-avatar :size="32" :src="auth.userInfo?.avatar">{{ avatarText }}</el-avatar>
              <span class="layout__user-name">{{ auth.userInfo?.nickname || '管理员' }}</span>
              <el-icon><ArrowDown /></el-icon>
            </button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="dashboard">返回总览</el-dropdown-item>
                <el-dropdown-item divided command="logout">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </header>

      <main class="ax-admin-main">
        <router-view v-slot="{ Component }">
          <transition name="page" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </main>
    </section>
  </div>
</template>

<style scoped>
.page-enter-active,
.page-leave-active {
  transition: opacity 180ms ease;
}

.page-enter-from,
.page-leave-to {
  opacity: 0;
}

.ax-admin-user {
  padding: 4px 6px;
  background: transparent;
  border: 0;
  border-radius: 8px;
}

.ax-admin-user:hover {
  background: var(--admin-surface-hover);
}
</style>
