<template>
  <div class="dfx-page">
    <PageHeader :title="$t('用户详情 · ') + (detail?.user?.nickname || '')" :subtitle='$t("用户资料 / 认证信息 / 真实消费")'>
      <template #actions>
        <el-button :icon="Back" @click="$router.back()">{{ $t("返回") }}</el-button>
      </template>
    </PageHeader>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">{{ $t("用户详情加载失败") }}</div>
        <div class="ax-page-feedback__description">{{ $t(loadError) }}{{ $t("，未完整返回的数据不会按空资料展示。") }}</div>
      </div>
      <el-button :loading="loading" @click="loadData">{{ $t("重新加载") }}</el-button>
    </div>

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
              <div class="profile__meta">ID: {{ $t(detail.user.userId) }} · {{ maskMobile(detail.user.mobile) }}</div>
            </div>
          </div>
          <div class="profile-grid">
            <div class="profile-item"><span class="label">{{ $t("性别") }}</span><span>{{ $t(genderText) }}</span></div>
            <div class="profile-item"><span class="label">{{ $t("生日") }}</span><span>{{ $t((detail.user.birthday || '-')) }}</span></div>
            <div class="profile-item"><span class="label">{{ $t("地区") }}</span><span>{{ $t((detail.user.region || '-')) }}</span></div>
            <div class="profile-item"><span class="label">{{ $t("简介") }}</span><span>{{ $t((detail.user.bio || '-')) }}</span></div>
          </div>
        </div>

        <!-- 消费画像 -->
        <div class="stat-row">
          <StatCard :label='$t("已付订单")' :value="detail.totalOrders" icon="List" icon-color="#C45A3C" :suffix='$t(" 单")' />
          <StatCard :label='$t("净消费")' :value="detail.totalSpent" icon="Money" icon-color="#C8A96E" prefix="¥" />
          <StatCard :label='$t("最近活跃")' :value="formatDate(detail.lastActiveTime)" icon="Clock" icon-color="#5B8C5A" />
          <StatCard :label='$t("偏好标签")' :value="detail.preferenceTags.length" icon="Star" icon-color="#D4A843" :suffix='$t(" 个")' />
        </div>
        <p class="stats-note">{{ $t('订单数为真实渠道已付款订单，消费为实付减成功退款；不含模拟付款、体验订单和测试余额。') }}<span v-if="detail.statsUpdatedAt"> {{ $t('统计时间') }}：{{ formatDate(detail.statsUpdatedAt) }}</span></p>
        <div class="dfx-card detail-section"><div class="section-title">{{ $t('登录身份') }}</div><div class="profile-grid"><div class="profile-item"><span class="label">{{ $t('凭据状态') }}</span><span>{{ $t(credentialLabel(detail.identity)) }}</span></div><div class="profile-item"><span class="label">{{ $t('本人邮箱') }}</span><span>{{ detail.identity.email || $t('未绑定') }}<el-tag v-if="detail.identity.email" :type="detail.identity.emailVerified ? 'success' : 'info'" size="small">{{ $t(detail.identity.emailVerified ? '已验证' : '未验证') }}</el-tag></span></div><div v-if="detail.identity.verifiedAt" class="profile-item"><span class="label">{{ $t('验证时间') }}</span><span>{{ formatDate(detail.identity.verifiedAt) }}</span></div></div><p class="stats-note">{{ $t(recoveryLabel(detail.identity)) }}</p></div>

        <!-- 偏好标签 -->
        <div class="dfx-card detail-section">
          <div class="section-title">{{ $t("偏好标签") }}</div>
          <div v-if="detail.preferenceTags.length" class="tags">
            <el-tag v-for="t in detail.preferenceTags" :key="t" effect="dark" type="warning" round>{{ $t(t) }}</el-tag>
          </div>
          <el-empty v-else :description='$t("暂无偏好标签")' :image-size="60" />
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
import { credentialLabel, recoveryLabel } from '@/utils/accountIdentity'
import type { AdminUserDetailResp } from '@/types'

const route = useRoute()
const loading = ref(false)
const detail = ref<AdminUserDetailResp | null>(null)
const loadError = ref('')

const genderText = computed(() => {
  const g = detail.value?.user.gender
  return g === 'male' ? '男' : g === 'female' ? '女' : '未知'
})

async function loadData() {
  loading.value = true
  loadError.value = ''
  try {
    const data = await getUserDetail(route.params.id as string)
    if (!data?.user || typeof data.user.nickname !== 'string' || !data.user.nickname.trim() || !data.identity || !Number.isFinite(data.totalOrders) || !Number.isFinite(data.totalSpent)) {
      throw new Error('用户详情数据结构不完整')
    }
    detail.value = { ...data, preferenceTags: Array.isArray(data.preferenceTags) ? data.preferenceTags : [] }
  } catch (error) {
    detail.value = null
    loadError.value = error instanceof Error ? error.message : '加载用户详情失败'
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
.stats-note{color:var(--color-text-secondary);line-height:1.8;margin:0}
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
  font-size: var(--type-size-section);
  font-weight: var(--type-weight-semibold);
  color: var(--color-text-primary);
}
.profile__meta {
  margin-top: 6px;
  font-size: var(--type-size-label);
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
  font-size: var(--type-size-caption);
  color: var(--color-text-tertiary);
}
.stat-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 16px;
}
.section-title {
  font-size: var(--type-size-control);
  font-weight: var(--type-weight-semibold);
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
@media (max-width: 767px) {
  .stat-row { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .profile-grid { grid-template-columns: minmax(0, 1fr); }
}
</style>
