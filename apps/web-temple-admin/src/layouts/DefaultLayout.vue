<script setup lang="ts">
import { ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import BrandLogo from '../../../../packages/admin-ui/components/BrandLogo.vue'
import AppearanceSelector from '../../../../packages/admin-ui/components/AppearanceSelector.vue'
import { computed } from 'vue'
import { templeMenu, activeTempleMenu } from '@/navigation'
import { useAdminNavigation } from '../../../../packages/admin-ui/navigation'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

import {
  ArrowDown,
  Calendar,
  ChatDotRound,
  OfficeBuilding,
  User,
  Expand,
  Fold,
  MagicStick,
  Menu,
  Odometer,
  Setting,
  TrendCharts
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const { collapsed, mobile, drawerOpen, sidebarRef, toggleRef, toggleNavigation, closeNavigation } = useAdminNavigation(() => route.fullPath)

const icons = { Odometer, OfficeBuilding, User, Calendar, ChatDotRound, TrendCharts, Setting }
const menus = computed(() => templeMenu.map(group => ({ ...group, children: group.children.filter(item => !item.permission || auth.can(item.permission)) })).filter(group => group.children.length))
const activeMenu = computed(() => activeTempleMenu(route.path))
const pageTitle = computed(() => (route.meta.title as string) || '寺院管理台')



async function handleLogout() {
  try {
    await ElMessageBox.confirm(uiText('确定要退出登录吗？'), uiText('退出登录'), {
      confirmButtonText: uiText('退出'),
      cancelButtonText: uiText('取消'),
      type: 'warning'
    })
    auth.logout()
    await router.replace('/login')
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
    <button class="ax-admin-overlay" type="button" :aria-label='$t("关闭导航")' tabindex="-1" :aria-hidden="!drawerOpen" @click="closeNavigation"></button>

    <aside id="admin-navigation" ref="sidebarRef" class="ax-admin-sidebar" tabindex="-1" :role="mobile && drawerOpen ? 'dialog' : undefined" :aria-modal="mobile && drawerOpen ? true : undefined" :aria-hidden="mobile && !drawerOpen ? true : undefined" :inert="mobile && !drawerOpen" :aria-label='$t("寺院管理台主导航")'>
      <div class="ax-admin-logo">
        <BrandLogo class="ax-admin-logo__image" identity="temple" :label='$t("问玄东方寺院管理台")' />
        <div class="ax-admin-logo__copy">
          <div class="ax-admin-logo__title">{{ $t("问玄东方") }}</div>
          <div class="ax-admin-logo__subtitle">{{ $t("寺院管理台") }}</div>
        </div>
      </div>

      <button v-if="mobile" class="ax-admin-sidebar__close" type="button" :aria-label='$t("关闭主导航")' @click="closeNavigation">
        <span aria-hidden="true">×</span><span>{{ $t("关闭导航") }}</span>
      </button>

      <el-menu
        :default-active="activeMenu"
        :collapse="collapsed && !mobile"
        :collapse-transition="false"
        router
        class="ax-admin-menu"
        background-color="transparent"
        text-color="#C5B097"
        active-text-color="#F5E0D6"
        unique-opened
      >
        <template v-for="group in menus" :key="group.id">
          <el-menu-item v-if="group.id === 'today'" index="/dashboard">
            <el-icon><Odometer /></el-icon><template #title>{{ $t(group.label) }}</template>
          </el-menu-item>
          <el-sub-menu v-else :index="group.id">
            <template #title><el-icon><component :is="icons[group.icon as keyof typeof icons]" /></el-icon><span>{{ $t(group.label) }}</span></template>
            <el-menu-item v-for="item in group.children" :key="item.path" :index="item.path">{{ $t(item.label) }}</el-menu-item>
          </el-sub-menu>
        </template>
      </el-menu>

      <div class="ax-admin-sidebar__footer">
        <div class="ax-admin-user">
          <el-avatar :size="36" :src="auth.userInfo?.avatar">
            {{ auth.userInfo?.nickname?.charAt(0) || $t('寺') }}
          </el-avatar>
          <div class="ax-admin-user__copy">
            <div class="ax-admin-user__name">{{ auth.userInfo?.nickname || $t('寺院管理员') }}</div>
            <div class="ax-admin-user__role">{{ auth.templeName }}</div>
          </div>
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
            :aria-label="$t((mobile ? ((drawerOpen ? $t('关闭主导航') : $t('打开主导航'))) : ((collapsed ? $t('展开主导航') : $t('收起主导航')))))"
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
            <div class="ax-admin-header__eyebrow">{{ $t("寺院管理台") }}</div>
            <div class="ax-admin-header__title">{{ $t(pageTitle) }}</div>
          </div>
        </div>

        <div class="ax-admin-header__right">
          <AppearanceSelector />
          <el-tag class="ax-admin-header__meta" type="warning" effect="plain" round>{{ auth.templeName }}</el-tag>
          <el-dropdown trigger="click">
            <button class="ax-admin-user header-user" type="button">
              <el-avatar :size="32" :src="auth.userInfo?.avatar">
                {{ auth.userInfo?.nickname?.charAt(0) || $t('寺') }}
              </el-avatar>
              <span class="ax-admin-user-name">{{ auth.userInfo?.nickname || $t('管理员') }}</span>
              <el-icon><ArrowDown /></el-icon>
            </button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item @click="router.push('/settings')">{{ $t("系统设置") }}</el-dropdown-item>
                <el-dropdown-item divided @click="handleLogout">{{ $t("退出登录") }}</el-dropdown-item>
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
.header-user {
  padding: 4px 6px;
  color: var(--admin-text-secondary);
  background: transparent;
  border: 0;
  border-radius: 8px;
}

.header-user:hover {
  background: var(--admin-surface-hover);
}


</style>
