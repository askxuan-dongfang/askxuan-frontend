<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { ElMessageBox } from 'element-plus'
import {
  ArrowDown,
  Calendar,
  ChatDotRound,
  Coin,
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
const logoUrl = `${import.meta.env.BASE_URL}logos/logo-temple.png`
const collapsed = ref(false)
const mobile = ref(false)
const drawerOpen = ref(false)
let mobileQuery: MediaQueryList | undefined

const activeMenu = computed(() => {
  if (route.path.startsWith('/masters/')) return '/masters'
  if (route.path.startsWith('/services/')) return '/services'
  if (route.path.startsWith('/bookings/')) return '/bookings'
  if (route.path.startsWith('/blessing-tasks/')) return '/blessing-tasks'
  return route.path
})
const pageTitle = computed(() => (route.meta.title as string) || '寺院管理台')

function syncViewport(event?: MediaQueryListEvent) {
  mobile.value = event ? event.matches : Boolean(mobileQuery?.matches)
  if (!mobile.value) drawerOpen.value = false
}

function toggleNavigation() {
  if (mobile.value) drawerOpen.value = !drawerOpen.value
  else collapsed.value = !collapsed.value
}

async function handleLogout() {
  try {
    await ElMessageBox.confirm('确定要退出登录吗？', '退出登录', {
      confirmButtonText: '退出',
      cancelButtonText: '取消',
      type: 'warning'
    })
    auth.logout()
    await router.replace('/login')
  } catch {
    // 用户取消。
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

    <aside class="ax-admin-sidebar" aria-label="寺院管理台主导航">
      <div class="ax-admin-logo">
        <img class="ax-admin-logo__image" :src="logoUrl" alt="" />
        <div class="ax-admin-logo__copy">
          <div class="ax-admin-logo__title">问玄东方</div>
          <div class="ax-admin-logo__subtitle">寺院管理台</div>
        </div>
      </div>

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
        <el-menu-item index="/dashboard">
          <el-icon><Odometer /></el-icon>
          <template #title>今日工作台</template>
        </el-menu-item>

        <el-sub-menu index="temple-profile">
          <template #title>
            <el-icon><Coin /></el-icon>
            <span>寺院主页</span>
          </template>
          <el-menu-item index="/temple-info">基本信息</el-menu-item>
          <el-menu-item index="/temple-gallery">寺院图册</el-menu-item>
        </el-sub-menu>

        <el-sub-menu index="people-services">
          <template #title>
            <el-icon><MagicStick /></el-icon>
            <span>人员与服务</span>
          </template>
          <el-menu-item index="/masters">法师管理</el-menu-item>
          <el-menu-item index="/services">服务管理</el-menu-item>
        </el-sub-menu>

        <el-menu-item index="/bookings">
          <el-icon><Calendar /></el-icon>
          <template #title>预约履约</template>
        </el-menu-item>
        <el-menu-item index="/blessing-tasks">
          <el-icon><MagicStick /></el-icon>
          <template #title>加持任务</template>
        </el-menu-item>
        <el-menu-item index="/reviews">
          <el-icon><ChatDotRound /></el-icon>
          <template #title>评价互动</template>
        </el-menu-item>
        <el-menu-item index="/report">
          <el-icon><TrendCharts /></el-icon>
          <template #title>经营报表</template>
        </el-menu-item>
        <el-menu-item index="/settings">
          <el-icon><Setting /></el-icon>
          <template #title>设置</template>
        </el-menu-item>
      </el-menu>

      <div class="ax-admin-sidebar__footer">
        <div class="ax-admin-user">
          <el-avatar :size="36" :src="auth.userInfo?.avatar">
            {{ auth.userInfo?.nickname?.charAt(0) || '寺' }}
          </el-avatar>
          <div class="ax-admin-user__copy">
            <div class="ax-admin-user__name">{{ auth.userInfo?.nickname || '寺院管理员' }}</div>
            <div class="ax-admin-user__role">{{ auth.templeName }}</div>
          </div>
        </div>
      </div>
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
            <div class="ax-admin-header__eyebrow">寺院管理台</div>
            <div class="ax-admin-header__title">{{ pageTitle }}</div>
          </div>
        </div>

        <div class="ax-admin-header__right">
          <el-tag class="ax-admin-header__meta" type="warning" effect="plain" round>{{ auth.templeName }}</el-tag>
          <el-dropdown trigger="click">
            <button class="ax-admin-user header-user" type="button">
              <el-avatar :size="32" :src="auth.userInfo?.avatar">
                {{ auth.userInfo?.nickname?.charAt(0) || '寺' }}
              </el-avatar>
              <span class="ax-admin-user-name">{{ auth.userInfo?.nickname || '管理员' }}</span>
              <el-icon><ArrowDown /></el-icon>
            </button>
            <template #dropdown>
              <el-dropdown-menu>
                <el-dropdown-item @click="router.push('/settings')">系统设置</el-dropdown-item>
                <el-dropdown-item divided @click="handleLogout">退出登录</el-dropdown-item>
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

.page-enter-active,
.page-leave-active {
  transition: opacity 180ms ease;
}

.page-enter-from,
.page-leave-to {
  opacity: 0;
}
</style>
