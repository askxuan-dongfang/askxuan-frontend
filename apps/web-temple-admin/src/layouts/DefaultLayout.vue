<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ElMessageBox } from 'element-plus'
import {
  Odometer,
  Coin,
  Calendar,
  ChatDotRound,
  TrendCharts,
  Setting,
  ArrowDown
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const activeMenu = computed(() => route.path)

function handleLogout() {
  ElMessageBox.confirm('确定退出登录？', '提示', {
    confirmButtonText: '退出',
    cancelButtonText: '取消',
    type: 'warning'
  })
    .then(() => {
      auth.logout()
      router.replace('/login')
    })
    .catch(() => {})
}
</script>

<template>
  <el-container class="h-screen">
    <!-- 侧边栏 -->
    <el-aside width="220px" class="df-aside">
      <div class="df-logo">
        <img class="df-logo-mark" src="/logos/logo-temple.jpg" alt="问玄东方寺院管理台" />
        <div class="df-logo-text">
          <div class="df-logo-title">问玄东方</div>
          <div class="df-logo-sub">寺院管理台</div>
        </div>
      </div>
      <el-menu
        :default-active="activeMenu"
        router
        class="df-menu"
        background-color="transparent"
        text-color="#E8DDC9"
        active-text-color="#F5E0D6"
      >
        <el-menu-item index="/dashboard">
          <el-icon><Odometer /></el-icon>
          <span>工作台</span>
        </el-menu-item>
        <el-sub-menu index="temple">
          <template #title>
            <el-icon><Coin /></el-icon>
            <span>寺院管理</span>
          </template>
          <el-menu-item index="/temple-info">寺院信息</el-menu-item>
          <el-menu-item index="/masters">法师管理</el-menu-item>
          <el-menu-item index="/services">服务管理</el-menu-item>
        </el-sub-menu>
        <el-menu-item index="/bookings">
          <el-icon><Calendar /></el-icon>
          <span>预约管理</span>
        </el-menu-item>
        <el-menu-item index="/reviews">
          <el-icon><ChatDotRound /></el-icon>
          <span>评价/内容互动</span>
        </el-menu-item>
        <el-menu-item index="/report">
          <el-icon><TrendCharts /></el-icon>
          <span>数据报表</span>
        </el-menu-item>
        <el-menu-item index="/settings">
          <el-icon><Setting /></el-icon>
          <span>系统设置</span>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <!-- 顶栏 -->
      <el-header class="df-header">
        <div class="df-header-title">
          <span class="df-title-bar"></span>
          {{ route.meta.title || '寺院管理台' }}
        </div>
        <div class="df-header-right">
          <el-tag type="warning" effect="plain" round>{{ auth.templeName }}</el-tag>
          <el-dropdown trigger="click">
            <div class="df-user">
              <el-avatar :size="30" :src="auth.userInfo?.avatar">
                {{ auth.userInfo?.nickname?.charAt(0) || '管' }}
              </el-avatar>
              <span class="df-user-name">{{ auth.userInfo?.nickname || '管理员' }}</span>
              <el-icon><ArrowDown /></el-icon>
            </div>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item @click="router.push('/settings')">系统设置</el-dropdown-item>
                <el-dropdown-item divided @click="handleLogout">退出登录</el-dropdown-item>
              </el-dropdown-menu>
            </template>
          </el-dropdown>
        </div>
      </el-header>

      <!-- 主体 -->
      <el-main class="df-main">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </router-view>
      </el-main>
    </el-container>
  </el-container>
</template>

<style scoped>
.df-aside {
  background: linear-gradient(180deg, #2a1e1a 0%, #1c1210 100%);
  border-right: 1px solid rgba(200, 169, 110, 0.12);
  overflow-y: auto;
}

.df-logo {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 18px 18px 14px;
  border-bottom: 1px solid rgba(200, 169, 110, 0.1);
}
.df-logo-mark {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  object-fit: cover;
  border: 1px solid rgba(200, 169, 110, 0.35);
  flex-shrink: 0;
}
.df-logo-title {
  font-family: 'Noto Serif SC', serif;
  color: #f0e6da;
  font-size: 16px;
  font-weight: 700;
  line-height: 1.2;
}
.df-logo-sub {
  color: #8a7a6a;
  font-size: 12px;
  margin-top: 2px;
}

.df-menu {
  border-right: none;
  padding: 8px 0;
}
.df-menu :deep(.el-menu-item),
.df-menu :deep(.el-sub-menu__title) {
  height: 44px;
  line-height: 44px;
  margin: 2px 10px;
  border-radius: 8px;
}
.df-menu :deep(.el-menu-item.is-active) {
  background: rgba(196, 90, 60, 0.18);
  color: #f5e0d6;
  font-weight: 600;
}
.df-menu :deep(.el-menu-item:hover),
.df-menu :deep(.el-sub-menu__title:hover) {
  background: rgba(200, 169, 110, 0.08);
}

.df-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #ffffff;
  border-bottom: 1px solid #e8e0d8;
  height: 56px;
  padding: 0 24px;
}
.df-header-title {
  display: flex;
  align-items: center;
  font-family: 'Noto Serif SC', serif;
  font-size: 17px;
  font-weight: 600;
  color: #2a1e1a;
}
.df-header-right {
  display: flex;
  align-items: center;
  gap: 16px;
}
.df-user {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  padding: 4px 6px;
  border-radius: 8px;
}
.df-user:hover {
  background: #f5f0eb;
}
.df-user-name {
  font-size: 14px;
  color: #4a3a30;
}

.df-main {
  background: #f5f0eb;
  padding: 0;
  overflow-y: auto;
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.18s ease;
}
.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>
