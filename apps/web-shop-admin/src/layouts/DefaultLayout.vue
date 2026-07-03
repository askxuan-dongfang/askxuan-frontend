<script setup lang="ts">
// 默认布局：左侧暗色菜单栏 + 顶栏 + 主内容区
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ElMessageBox } from 'element-plus'
import {
  Odometer,
  Goods,
  Files,
  Box,
  MagicStick,
  List,
  Van,
  RefreshLeft,
  DataLine,
  SwitchButton
} from '@element-plus/icons-vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

// 当前激活菜单
const activeMenu = computed(() => {
  if (route.path.startsWith('/products')) return '/products'
  if (route.path.startsWith('/materials')) return '/materials'
  if (route.path.startsWith('/services')) return '/services'
  if (route.path.startsWith('/orders')) return '/orders'
  if (route.path.startsWith('/diy-orders')) return '/diy-orders'
  if (route.path.startsWith('/returns')) return '/returns'
  return route.path
})

// 当前页面标题
const pageTitle = computed(() => (route.meta.title as string) || '商城管理台')

// 退出登录
async function handleLogout() {
  try {
    await ElMessageBox.confirm('确定要退出登录吗？', '提示', {
      confirmButtonText: '退出',
      cancelButtonText: '取消',
      type: 'warning'
    })
    auth.logout()
    router.push('/login')
  } catch {
    // 用户取消
  }
}
</script>

<template>
  <div class="layout">
    <!-- 左侧菜单栏 -->
    <aside class="sidebar">
      <div class="sidebar-logo">
        <h1>问玄东方</h1>
        <p>商城管理台</p>
      </div>

      <el-menu
        :default-active="activeMenu"
        background-color="transparent"
        text-color="#C5B097"
        active-text-color="#C45A3C"
        router
        class="sidebar-menu"
      >
        <div class="sidebar-section">主菜单</div>
        <el-menu-item index="/dashboard">
          <el-icon><Odometer /></el-icon>
          <span>工作台</span>
        </el-menu-item>
        <el-menu-item index="/products">
          <el-icon><Goods /></el-icon>
          <span>商品管理</span>
        </el-menu-item>
        <el-menu-item index="/categories">
          <el-icon><Files /></el-icon>
          <span>分类管理</span>
        </el-menu-item>

        <div class="sidebar-section">DIY 中心</div>
        <el-menu-item index="/materials">
          <el-icon><Box /></el-icon>
          <span>材料管理</span>
        </el-menu-item>
        <el-menu-item index="/services">
          <el-icon><MagicStick /></el-icon>
          <span>祈福服务</span>
        </el-menu-item>

        <div class="sidebar-section">订单运营</div>
        <el-menu-item index="/orders">
          <el-icon><List /></el-icon>
          <span>商城订单</span>
        </el-menu-item>
        <el-menu-item index="/diy-orders">
          <el-icon><MagicStick /></el-icon>
          <span>DIY 订单</span>
        </el-menu-item>
        <el-menu-item index="/logistics">
          <el-icon><Van /></el-icon>
          <span>物流管理</span>
        </el-menu-item>
        <el-menu-item index="/returns">
          <el-icon><RefreshLeft /></el-icon>
          <span>退货管理</span>
        </el-menu-item>

        <div class="sidebar-section">数据</div>
        <el-menu-item index="/reports">
          <el-icon><DataLine /></el-icon>
          <span>数据报表</span>
        </el-menu-item>
      </el-menu>

      <!-- 用户信息 -->
      <div class="sidebar-footer">
        <div class="sidebar-user">
          <div class="sidebar-user-avatar">{{ auth.nickname?.charAt(0) || '商' }}</div>
          <div class="sidebar-user-info">
            <div class="sidebar-user-name">{{ auth.nickname }}</div>
            <div class="sidebar-user-role">商城运营</div>
          </div>
          <el-tooltip content="退出登录" placement="top">
            <el-icon class="logout-btn" @click="handleLogout"><SwitchButton /></el-icon>
          </el-tooltip>
        </div>
      </div>
    </aside>

    <!-- 主内容区 -->
    <main class="content">
      <!-- 顶栏 -->
      <header class="page-header">
        <div class="page-header-left">
          <h2>{{ pageTitle }}</h2>
        </div>
        <div class="page-header-right">
          <span class="header-date">{{ new Date().toLocaleDateString('zh-CN', { year: 'numeric', month: 'long', day: 'numeric', weekday: 'long' }) }}</span>
        </div>
      </header>

      <!-- 路由出口 -->
      <div class="page-body">
        <RouterView v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <component :is="Component" />
          </transition>
        </RouterView>
      </div>
    </main>
  </div>
</template>

<style scoped>
.layout {
  display: flex;
  min-height: 100vh;
}

/* ===== 侧边栏 ===== */
.sidebar {
  position: fixed;
  left: 0;
  top: 0;
  bottom: 0;
  width: var(--sidebar-width);
  background: var(--sidebar-bg);
  display: flex;
  flex-direction: column;
  z-index: 1000;
}

.sidebar-logo {
  padding: 24px 20px;
  border-bottom: 1px solid rgba(197, 176, 151, 0.15);
  text-align: center;
}
.sidebar-logo h1 {
  font-family: 'Noto Serif SC', serif;
  font-size: 22px;
  font-weight: 700;
  color: var(--accent);
  margin: 0 0 4px;
  letter-spacing: 4px;
}
.sidebar-logo p {
  font-size: 12px;
  color: var(--sidebar-text);
  opacity: 0.6;
  letter-spacing: 2px;
  margin: 0;
}

.sidebar-menu {
  flex: 1;
  border-right: none;
  overflow-y: auto;
  padding: 12px 0;
}

.sidebar-section {
  padding: 12px 20px 4px;
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 1px;
  color: var(--sidebar-text);
  opacity: 0.4;
}

/* 菜单项样式覆盖 */
.sidebar-menu :deep(.el-menu-item) {
  height: 44px;
  line-height: 44px;
  border-left: 3px solid transparent;
  border-radius: 0;
}
.sidebar-menu :deep(.el-menu-item:hover) {
  background: rgba(197, 176, 151, 0.08) !important;
  color: #dcc8b0 !important;
}
.sidebar-menu :deep(.el-menu-item.is-active) {
  background: rgba(196, 90, 60, 0.15) !important;
  border-left-color: var(--primary);
  font-weight: 500;
}

/* 用户信息 */
.sidebar-footer {
  padding: 16px 20px;
  border-top: 1px solid rgba(197, 176, 151, 0.15);
}
.sidebar-user {
  display: flex;
  align-items: center;
  gap: 10px;
}
.sidebar-user-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  background: var(--accent);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--sidebar-bg);
  font-weight: 600;
  font-size: 14px;
  flex-shrink: 0;
}
.sidebar-user-info {
  flex: 1;
  min-width: 0;
}
.sidebar-user-name {
  font-size: 13px;
  color: #dcc8b0;
  font-weight: 500;
}
.sidebar-user-role {
  font-size: 11px;
  color: var(--sidebar-text);
  opacity: 0.5;
}
.logout-btn {
  color: var(--sidebar-text);
  opacity: 0.6;
  cursor: pointer;
  font-size: 18px;
  transition: var(--transition);
}
.logout-btn:hover {
  opacity: 1;
  color: var(--primary);
}

/* ===== 内容区 ===== */
.content {
  margin-left: var(--sidebar-width);
  flex: 1;
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.page-header {
  background: var(--card-bg);
  padding: 0 32px;
  height: var(--header-height);
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid var(--border);
  position: sticky;
  top: 0;
  z-index: 100;
}
.page-header h2 {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-dark);
  margin: 0;
}
.header-date {
  font-size: 13px;
  color: var(--text-light);
}

.page-body {
  flex: 1;
  padding: 24px 32px;
}

/* 响应式 */
@media (max-width: 1024px) {
  :deep(.sidebar) {
    width: 64px;
  }
  :deep(.sidebar-logo h1),
  :deep(.sidebar-logo p),
  :deep(.sidebar-section),
  :deep(.sidebar-user-info),
  :deep(.logout-btn) {
    display: none;
  }
}
</style>
