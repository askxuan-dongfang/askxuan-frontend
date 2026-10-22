<script setup lang="ts">
import { ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../packages/localization/language'

import { adminWorkspaces, activeWorkspacePath, workspaceForPath, workspaceItemForPath } from '../../../../packages/admin-ui/workspaces'
import BrandLogo from '../../../../packages/admin-ui/components/BrandLogo.vue'
import AppearanceSelector from '../../../../packages/admin-ui/components/AppearanceSelector.vue'
import { computed } from 'vue'
import { useAdminNavigation } from '../../../../packages/admin-ui/navigation'
import { useRoute, useRouter } from 'vue-router'

import { canAccessRoute, defaultRoute } from '@/router/access'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const { collapsed, mobile, drawerOpen, sidebarRef, toggleRef, toggleNavigation, closeNavigation } = useAdminNavigation(() => route.fullPath)

const menuGroups = computed(() => adminWorkspaces.map(group => ({ ...group, children: group.children.filter(item => canAccessRoute(router.resolve(item.path), auth.roles, auth.access)) })).filter(group => group.children.length))
const homePath = computed(() => defaultRoute(auth.roles, auth.access))
const activeMenu = computed(() => activeWorkspacePath(route.path))
const pageWorkspace = computed(() => workspaceForPath(route.path))
const pageList = computed(() => workspaceItemForPath(route.path))
const avatarText = computed(() => (auth.userInfo?.nickname || '管').slice(0, 1))
const pageTitle = computed(() => (route.meta.title as string) || '平台管理台')
const pageParent = computed(() => pageWorkspace.value?.title || '平台管理台')



async function onCommand(cmd: string) {
  if (cmd === 'logout') {
    try {
      await ElMessageBox.confirm(uiText('确定要退出登录吗？'), uiText('退出登录'), {
        confirmButtonText: uiText('退出'),
        cancelButtonText: uiText('取消'),
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


</script>

<template>
  <div
    class="ax-admin-shell"
    :class="{ 'is-collapsed': collapsed && !mobile, 'is-drawer-open': drawerOpen }"
  >
    <button class="ax-admin-overlay" type="button" :aria-label='$t("关闭导航")' tabindex="-1" :aria-hidden="!drawerOpen" @click="closeNavigation"></button>

    <aside id="admin-navigation" ref="sidebarRef" class="ax-admin-sidebar" tabindex="-1" :role="mobile && drawerOpen ? 'dialog' : undefined" :aria-modal="mobile && drawerOpen ? true : undefined" :aria-hidden="mobile && !drawerOpen ? true : undefined" :inert="mobile && !drawerOpen" :aria-label='$t("平台管理台主导航")'>
      <div class="ax-admin-logo">
        <BrandLogo class="ax-admin-logo__image" identity="platform" :label='$t("问玄东方统一运营管理台")' />
        <div class="ax-admin-logo__copy">
          <div class="ax-admin-logo__title">{{ $t("问玄东方") }}</div>
          <div class="ax-admin-logo__subtitle">{{ $t("统一运营管理台") }}</div>
        </div>
      </div>

      <button v-if="mobile" class="ax-admin-sidebar__close" type="button" :aria-label='$t("关闭主导航")' @click="closeNavigation">
        <span aria-hidden="true">×</span><span>{{ $t("关闭导航") }}</span>
      </button>

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
        <el-sub-menu v-for="group in menuGroups" :key="group.title" :index="group.title">
          <template #title>
            <el-icon><component :is="group.icon" /></el-icon>
            <span>{{ $t(group.title) }}</span>
          </template>
          <el-menu-item v-for="item in group.children" :key="item.path" :index="item.pending ? `pending:${group.title}` : item.path" :disabled="item.pending">
            {{ $t(item.title) }}
          </el-menu-item>
        </el-sub-menu>
      </el-menu>

      <div class="ax-admin-version">{{ $t("统一运营管理台") }}</div>
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
            <nav class="ax-admin-header__eyebrow" :aria-label="$t('面包屑')">
              <span>{{ $t(pageParent) }}</span>
              <template v-if="pageList && pageList.path !== route.path"> / <router-link :to="pageList.path">{{ $t(pageList.title) }}</router-link></template>
            </nav>
            <div class="ax-admin-header__title">{{ $t(pageTitle) }}</div>
          </div>
        </div>

        <div class="ax-admin-header__right">
          <AppearanceSelector />
          <el-dropdown @command="onCommand">
            <button class="ax-admin-user" type="button">
              <el-avatar :size="32" :src="auth.userInfo?.avatar">{{ $t(avatarText) }}</el-avatar>
              <span class="layout__user-name">{{ auth.userInfo?.nickname || $t('管理员') }}</span>
              <el-icon><ArrowDown /></el-icon>
            </button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="dashboard">{{ $t("返回总览") }}</el-dropdown-item>
                <el-dropdown-item divided command="logout">{{ $t("退出登录") }}</el-dropdown-item>
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
.ax-admin-header__eyebrow a{color:inherit;text-underline-offset:3px}.ax-admin-menu .el-menu-item.is-disabled{height:auto;min-height:44px;line-height:1.5;white-space:normal;padding-top:12px;padding-bottom:12px;opacity:.7}


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
