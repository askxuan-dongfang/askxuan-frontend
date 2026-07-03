<template>
  <el-container class="layout">
    <!-- 侧边栏 -->
    <el-aside :width="collapsed ? '64px' : '230px'" class="layout__aside">
      <div class="layout__logo">
        <span class="layout__logo-icon">玄</span>
        <transition name="fade">
          <span v-if="!collapsed" class="layout__logo-text dfx-serif">问玄东方</span>
        </transition>
      </div>
      <el-scrollbar class="layout__menu-scroll">
        <el-menu
          :default-active="activeMenu"
          :collapse="collapsed"
          :collapse-transition="false"
          background-color="transparent"
          text-color="var(--color-text-secondary)"
          active-text-color="var(--color-accent)"
          router
          unique-opened
        >
          <el-menu-item index="/dashboard">
            <el-icon><Odometer /></el-icon>
            <template #title>平台总览</template>
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
      </el-scrollbar>
    </el-aside>

    <el-container>
      <!-- 顶部 -->
      <el-header class="layout__header">
        <div class="layout__header-left">
          <el-icon class="layout__collapse" :size="20" @click="collapsed = !collapsed">
            <Fold v-if="!collapsed" />
            <Expand v-else />
          </el-icon>
          <el-breadcrumb separator="/">
            <el-breadcrumb-item :to="{ path: '/dashboard' }">首页</el-breadcrumb-item>
            <el-breadcrumb-item v-if="route.meta.parent">{{ route.meta.parent }}</el-breadcrumb-item>
            <el-breadcrumb-item>{{ route.meta.title }}</el-breadcrumb-item>
          </el-breadcrumb>
        </div>
        <div class="layout__header-right">
          <el-dropdown @command="onCommand">
            <span class="layout__user">
              <el-avatar :size="30" :src="auth.userInfo?.avatar">{{ avatarText }}</el-avatar>
              <span class="layout__user-name">{{ auth.userInfo?.nickname || '管理员' }}</span>
              <el-icon><ArrowDown /></el-icon>
            </span>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item command="dashboard">返回总览</el-dropdown-item>
                <el-dropdown-item divided command="logout">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <!-- 内容区 -->
      <el-main class="layout__main">
        <router-view v-slot="{ Component }">
          <transition name="page" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>
  </el-container>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessageBox } from 'element-plus'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const collapsed = ref(false)

const menuGroups = [
  {
    title: '寺院管理',
    icon: 'OfficeBuilding',
    children: [
      { path: '/temple/list', title: '寺院列表' },
      { path: '/temple/review', title: '寺院审核' }
    ]
  },
  {
    title: '法师管理',
    icon: 'Avatar',
    children: [
      { path: '/master/list', title: '法师列表' },
      { path: '/master/review', title: '法师审核' }
    ]
  },
  {
    title: '用户管理',
    icon: 'User',
    children: [{ path: '/user/list', title: '用户列表' }]
  },
  {
    title: '内容审核',
    icon: 'Checked',
    children: [
      { path: '/audit/comment', title: '评价审核' },
      { path: '/audit/design', title: '素材审核' },
      { path: '/audit/report', title: '举报处理' }
    ]
  },
  {
    title: '财务管理',
    icon: 'Money',
    children: [
      { path: '/finance/overview', title: '财务概览' },
      { path: '/finance/temple', title: '寺院结算' },
      { path: '/finance/master', title: '法师结算' },
      { path: '/finance/reconcile', title: '对账中心' }
    ]
  },
  {
    title: '营销管理',
    icon: 'Promotion',
    children: [
      { path: '/marketing/banner', title: 'Banner 管理' },
      { path: '/marketing/activity', title: '活动管理' },
      { path: '/marketing/coupon', title: '优惠券管理' }
    ]
  },
  {
    title: '系统设置',
    icon: 'Setting',
    children: [
      { path: '/settings/role', title: '角色权限' },
      { path: '/settings/dict', title: '数据字典' },
      { path: '/settings/log', title: '操作日志' },
      { path: '/settings/backup', title: '数据备份' }
    ]
  }
]

const activeMenu = computed(() => route.path)
const avatarText = computed(() => (auth.userInfo?.nickname || '管').slice(0, 1))

async function onCommand(cmd: string) {
  if (cmd === 'logout') {
    await ElMessageBox.confirm('确定要退出登录吗？', '提示', { type: 'warning' })
    auth.logout()
    router.push('/login')
  } else if (cmd === 'dashboard') {
    router.push('/dashboard')
  }
}
</script>

<style scoped>
.layout {
  height: 100vh;
}
.layout__aside {
  background: var(--color-bg-secondary);
  border-right: 1px solid var(--color-border);
  transition: width 0.25s;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}
.layout__logo {
  display: flex;
  align-items: center;
  gap: 10px;
  height: 60px;
  padding: 0 18px;
  border-bottom: 1px solid var(--color-border-divider);
  flex-shrink: 0;
}
.layout__logo-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-md);
  background: linear-gradient(135deg, var(--color-brand), var(--color-cinnabar));
  color: var(--color-text-primary);
  font-family: var(--font-serif);
  font-weight: 900;
  font-size: 18px;
  flex-shrink: 0;
}
.layout__logo-text {
  font-size: 15px;
  font-weight: 700;
  color: var(--color-text-primary);
  white-space: nowrap;
}
.layout__menu-scroll {
  flex: 1;
}
.layout__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 56px;
  background: var(--color-bg-secondary);
  border-bottom: 1px solid var(--color-border);
  padding: 0 20px;
}
.layout__header-left {
  display: flex;
  align-items: center;
  gap: 16px;
}
.layout__collapse {
  cursor: pointer;
  color: var(--color-text-secondary);
}
.layout__collapse:hover {
  color: var(--color-accent);
}
.layout__header-right {
  display: flex;
  align-items: center;
}
.layout__user {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  color: var(--color-text-secondary);
}
.layout__user-name {
  font-size: 14px;
}
.layout__main {
  background: var(--color-bg-primary);
  padding: 0;
  overflow-y: auto;
}

/* 菜单样式 */
:deep(.el-menu) {
  border-right: none;
}
:deep(.el-menu-item:hover),
:deep(.el-sub-menu__title:hover) {
  background-color: var(--color-bg-tertiary) !important;
}
:deep(.el-menu-item.is-active) {
  background-color: var(--color-bg-tertiary) !important;
  border-right: 2px solid var(--color-accent);
}
:deep(.el-sub-menu .el-menu-item) {
  padding-left: 52px !important;
}

/* 过渡 */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
.page-enter-active {
  transition: opacity 0.2s;
}
.page-enter-from {
  opacity: 0;
}
</style>
