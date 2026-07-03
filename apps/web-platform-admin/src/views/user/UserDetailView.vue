<template>
  <div class="dfx-page">
    <PageHeader :title="`用户详情 · ${detail?.user.nickname || ''}`" subtitle="用户资料 / 消费画像 / 偏好">
      <template #actions>
        <el-button :icon="Back" @click="$router.back()">返回</el-button>
      </template>
    </PageHeader>

    <div v-loading="loading">
      <div v-if="detail" class="detail-wrap">
        <!-- 资料 -->
        <div class="dfx-card detail-section">
          <div class="profile">
            <el-avatar :size="72" :src="detail.user.avatar">{{ detail.user.nickname?.slice(0, 1) }}</el-avatar>
            <div class="profile__main">
              <div class="profile__name dfx-serif">
                {{ detail.user.nickname }}
                <StatusTag :status="detail.status" />
              </div>
              <div class="profile__meta">ID: {{ detail.user.userId }} · {{ maskMobile(detail.user.mobile) }}</div>
            </div>
          </div>
          <div class="profile-grid">
            <div class="profile-item"><span class="label">性别</span><span>{{ genderText }}</span></div>
            <div class="profile-item"><span class="label">生日</span><span>{{ detail.user.birthday || '-' }}</span></div>
            <div class="profile-item"><span class="label">地区</span><span>{{ detail.user.region || '-' }}</span></div>
            <div class="profile-item"><span class="label">简介</span><span>{{ detail.user.bio || '-' }}</span></div>
          </div>
        </div>

        <!-- 消费画像 -->
        <div class="stat-row">
          <StatCard label="累计订单" :value="detail.totalOrders" icon="List" icon-color="#C45A3C" suffix=" 单" />
          <StatCard label="累计消费" :value="detail.totalSpent" icon="Money" icon-color="#C8A96E" prefix="¥" />
          <StatCard label="最近活跃" :value="formatDate(detail.lastActiveTime)" icon="Clock" icon-color="#5B8C5A" />
          <StatCard label="偏好标签" :value="detail.preferenceTags.length" icon="Star" icon-color="#D4A843" suffix=" 个" />
        </div>

        <!-- 偏好标签 -->
        <div class="dfx-card detail-section">
          <div class="section-title">偏好标签</div>
          <div v-if="detail.preferenceTags.length" class="tags">
            <el-tag v-for="t in detail.preferenceTags" :key="t" effect="dark" type="warning" round>{{ t }}</el-tag>
          </div>
          <el-empty v-else description="暂无偏好标签" :image-size="60" />
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { Back } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import StatCard from '@/components/StatCard.vue'
import { getUserDetail } from '@/api/user'
import { formatDate, maskMobile } from '@/utils/format'
import type { AdminUserDetailResp } from '@/types'

const route = useRoute()
const loading = ref(false)
const detail = ref<AdminUserDetailResp | null>(null)

const genderText = computed(() => {
  const g = detail.value?.user.gender
  return g === 'male' ? '男' : g === 'female' ? '女' : '未知'
})

async function loadData() {
  loading.value = true
  try {
    detail.value = await getUserDetail(route.params.id as string)
  } finally {
    loading.value = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.detail-wrap {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.detail-section {
  padding: 20px;
}
.profile {
  display: flex;
  align-items: center;
  gap: 18px;
  margin-bottom: 20px;
  padding-bottom: 20px;
  border-bottom: 1px solid var(--color-border-divider);
}
.profile__name {
  display: flex;
  align-items: center;
  gap: 10px;
  font-size: 20px;
  font-weight: 700;
  color: var(--color-text-primary);
}
.profile__meta {
  margin-top: 6px;
  font-size: 13px;
  color: var(--color-text-tertiary);
}
.profile-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}
.profile-item {
  display: flex;
  flex-direction: column;
  gap: 6px;
}
.profile-item .label {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
.stat-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}
.section-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--color-text-primary);
  margin-bottom: 16px;
  padding-left: 10px;
  border-left: 3px solid var(--color-accent);
}
.tags {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
</style>
