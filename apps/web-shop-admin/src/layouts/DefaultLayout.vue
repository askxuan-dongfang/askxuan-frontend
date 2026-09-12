<script setup lang="ts">
import { computed } from 'vue'
import { useAdminNavigation } from '../../../../packages/admin-ui/navigation'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ElMessageBox } from 'element-plus'
import {
  Box,
  DataLine,
  Expand,
  Files,
  Fold,
  Goods,
  List,
  MagicStick,
  Menu,
  Odometer,
  RefreshLeft,
  SwitchButton,
  Van
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const logoUrl = `${import.meta.env.BASE_URL}logos/logo-shop.png`
const { collapsed, mobile, drawerOpen, sidebarRef, toggleRef, toggleNavigation, closeNavigation } = useAdminNavigation(() => route.fullPath)

const activeMenu = computed(() => {
  if (route.path.startsWith('/products')) return '/products'
  if (route.path.startsWith('/materials')) return '/materials'
  if (route.path.startsWith('/services')) return '/services'
  if (route.path.startsWith('/orders')) return '/orders'
  if (route.path.startsWith('/diy-orders')) return '/diy-orders'
  if (route.path.startsWith('/returns')) return '/returns'
  return route.path
})
const pageTitle = computed(() => (route.meta.title as string) || '商城管理台')



async function handleLogout() {
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
}


</script>

<template>
  <div
    class="ax-admin-shell"
    :class="{ 'is-collapsed': collapsed && !mobile, 'is-drawer-open': drawerOpen }"
  >
    <button class="ax-admin-overlay" type="button" aria-label="关闭导航" tabindex="-1" :aria-hidden="!drawerOpen" @click="closeNavigation"></button>

    <aside id="admin-navigation" ref="sidebarRef" class="ax-admin-sidebar" tabindex="-1" :role="mobile && drawerOpen ? 'dialog' : undefined" :aria-modal="mobile && drawerOpen ? true : undefined" :aria-hidden="mobile && !drawerOpen ? true : undefined" :inert="mobile && !drawerOpen" aria-label="商城管理台主导航">
      <div class="ax-admin-logo">
        <img class="ax-admin-logo__image" :src="logoUrl" alt="" />
        <div class="ax-admin-logo__copy">
          <div class="ax-admin-logo__title">问玄东方</div>
          <div class="ax-admin-logo__subtitle">商城管理台</div>
        </div>
      </div>

      <button v-if="mobile" class="ax-admin-sidebar__close" type="button" aria-label="关闭主导航" @click="closeNavigation">
        <span aria-hidden="true">×</span><span>关闭导航</span>
      </button>

      <el-menu
        :default-active="activeMenu"
        :collapse="collapsed && !mobile"
        :collapse-transition="false"
        background-color="transparent"
        text-color="#C5B097"
        active-text-color="#F5E0D6"
        router
        class="ax-admin-menu"
      >
        <div class="ax-admin-menu__section">今日</div>
        <el-menu-item index="/dashboard">
          <el-icon><Odometer /></el-icon>
          <template #title>今日工作台</template>
        </el-menu-item>

        <div class="ax-admin-menu__section">商品中心</div>
        <el-menu-item index="/products">
          <el-icon><Goods /></el-icon>
          <template #title>商品管理</template>
        </el-menu-item>
        <el-menu-item index="/categories">
          <el-icon><Files /></el-icon>
          <template #title>分类管理</template>
        </el-menu-item>

        <div class="ax-admin-menu__section">积分运营</div>
        <el-menu-item index="/points-mall"><el-icon><Goods /></el-icon><template #title>积分商城</template></el-menu-item>
        <div class="ax-admin-menu__section">DIY 中心</div>
        <el-menu-item index="/diy-orders">
          <el-icon><MagicStick /></el-icon>
          <template #title>DIY 订单</template>
        </el-menu-item>
        <el-menu-item index="/materials">
          <el-icon><Box /></el-icon>
          <template #title>材料管理</template>
        </el-menu-item>
        <el-menu-item index="/services">
          <el-icon><MagicStick /></el-icon>
          <template #title>加持服务</template>
        </el-menu-item>

        <div class="ax-admin-menu__section">履约与售后</div>
        <el-menu-item index="/orders">
          <el-icon><List /></el-icon>
          <template #title>商城订单</template>
        </el-menu-item>
        <el-menu-item index="/logistics">
          <el-icon><Van /></el-icon>
          <template #title>物流管理</template>
        </el-menu-item>
        <el-menu-item index="/returns">
          <el-icon><RefreshLeft /></el-icon>
          <template #title>退货管理</template>
        </el-menu-item>

        <div class="ax-admin-menu__section">数据</div>
        <el-menu-item index="/reports">
          <el-icon><DataLine /></el-icon>
          <template #title>经营报表</template>
        </el-menu-item>
      </el-menu>

      <div class="ax-admin-sidebar__footer">
        <div class="ax-admin-user">
          <div class="ax-admin-user__avatar">{{ auth.nickname?.charAt(0) || '商' }}</div>
          <div class="ax-admin-user__copy">
            <div class="ax-admin-user__name">{{ auth.nickname || '商城管理员' }}</div>
            <div class="ax-admin-user__role">商城运营</div>
          </div>
          <el-tooltip content="退出登录" placement="top">
            <button class="ax-admin-user__action icon-button" type="button" aria-label="退出登录" @click="handleLogout">
              <el-icon><SwitchButton /></el-icon>
            </button>
          </el-tooltip>
        </div>
      </div>
    </aside>

    <section class="ax-admin-content" :inert="mobile && drawerOpen">
      <header class="ax-admin-header">
        <div class="ax-admin-header__left">
          <button
            ref="toggleRef"
            class="ax-admin-nav-toggle"
            aria-controls="admin-navigation"
            type="button"
            :aria-label="mobile ? (drawerOpen ? '关闭主导航' : '打开主导航') : (collapsed ? '展开主导航' : '收起主导航')"
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
            <div class="ax-admin-header__eyebrow">商城管理台</div>
            <div class="ax-admin-header__title">{{ pageTitle }}</div>
          </div>
        </div>
        <div class="ax-admin-header__right">
          <span class="header-date">
            {{ new Date().toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' }) }}
          </span>
        </div>
      </header>

      <main class="ax-admin-main">
        <RouterView v-slot="{ Component }">
          <transition name="page" mode="out-in">
            <component :is="Component" />
          </transition>
        </RouterView>
      </main>
    </section>
  </div>
</template>

<style scoped>
.icon-button {
  width: 36px;
  height: 36px;
  padding: 0;
  display: grid;
  place-items: center;
  background: transparent;
  border: 0;
  border-radius: 8px;
}

.icon-button:hover {
  color: var(--admin-text);
  background: rgba(var(--admin-accent-rgb),0.08);
}


</style>
