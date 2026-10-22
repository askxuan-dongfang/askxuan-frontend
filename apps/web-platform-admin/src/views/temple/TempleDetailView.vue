<template>
  <div class="dfx-page">
    <PageHeader :title="$t(($t('寺院详情 · ') + String((detail?.temple?.name || '')) + $t('')))" :subtitle='$t("寺院基础信息 / 图册 / 服务项目")'>
      <template #actions>
        <el-button :icon="Back" @click="$router.back()">{{ $t("返回") }}</el-button>
      </template>
    </PageHeader>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">{{ $t("寺院详情加载失败") }}</div>
        <div class="ax-page-feedback__description">{{ $t(loadError) }}{{ $t("，未完整返回的数据不会按空资料展示。") }}</div>
      </div>
      <el-button :loading="loading" @click="loadData">{{ $t("重新加载") }}</el-button>
    </div>

    <div v-loading="loading">
      <div v-if="detail" class="detail-wrap">
        <!-- 基础信息 -->
        <div class="dfx-card detail-section">
          <div class="detail-cover">
            <el-image v-if="detail.temple.coverImage" :src="detail.temple.coverImage" fit="cover" class="detail-cover__img">
              <template #error><div class="detail-cover__fallback">{{ $t("寺") }}</div></template>
            </el-image>
            <div v-else class="detail-cover__fallback">{{ $t("寺") }}</div>
          </div>
          <div class="detail-info">
            <h2 class="detail-info__name dfx-serif">{{ $t(detail.temple.name) }}</h2>
            <div class="detail-info__meta">
              <TempleStateControl :temple="detail.temple" :editable="auth.roles.includes('platform_super') || auth.access?.permissions.includes('platform.temples.write')" @updated="loadData" />
              <el-tag size="small" effect="plain">{{ $t(detail.temple.type) }}</el-tag>
              <span class="star">★ {{ $t(detail.temple.rating?.toFixed(1)) }}</span>
            </div>
            <div class="detail-info__row"><span class="label">{{ $t("寺院编码：") }}</span>{{ $t(detail.temple.id) }}</div>
            <div class="detail-info__row"><span class="label">{{ $t("所在地区：") }}</span>{{ $t(detail.temple.region) }}</div>
            <div class="detail-info__row"><span class="label">{{ $t("详细地址：") }}</span>{{ detail.temple.address || '-' }}</div>
            <div class="detail-info__row"><span class="label">{{ $t('宗派补充说明') }}</span>{{ detail.temple.sect || '—' }}</div>
            <div class="detail-info__row affiliation-summary"><ProviderAffiliation :belief="detail.temple.beliefCode" :codes="detail.temple.traditionCodes || []" readonly :catalog-token="auth.roles.includes('platform_super') ? auth.token : undefined" :catalog-url="auth.roles.includes('platform_super') ? '/api/v1/admin/platform/beliefs/directory-tags' : '/api/v1/beliefs/directory-tags'" /></div>
            <div class="detail-info__row"><ProviderDirectoryTags kind="temple" :id="detail.temple.id" :name="detail.temple.name" :belief="detail.temple.beliefCode" @updated="loadData"/></div>
            <div class="detail-info__row"><span class="label">{{ $t("简介：") }}</span>{{ $t((detail.temple.description || '-')) }}</div>
          </div>
        </div>

        <!-- 图册 -->
        <SubjectAccounts kind="temple" :id="detail.temple.id" />
        <div class="dfx-card detail-section">
          <div class="section-title">{{ $t("寺院图册（") }}{{ $t(detail.images.length) }}）</div>
          <div v-if="detail.images.length" class="gallery">
            <div v-for="img in detail.images" :key="img.id" class="gallery__item">
              <el-image :src="img.url" fit="cover" class="gallery__img" :preview-src-list="[img.url]" preview-teleported>
                <template #error><div class="gallery__fallback">{{ $t("图") }}</div></template>
              </el-image>
              <el-tag size="small" effect="dark" class="gallery__type">{{ $t(img.type) }}</el-tag>
            </div>
          </div>
          <el-empty v-else :description='$t("暂无图片")' :image-size="60" />
        </div>

        <!-- 服务项目 -->
        <div class="dfx-card detail-section">
          <div class="section-title">{{ $t("服务项目（") }}{{ $t(detail.services.length) }}）</div>
          <el-table :data="detail.services" style="width: 100%">
            <el-table-column :label='$t("服务名称")' prop="serviceName" min-width="160" />
            <el-table-column :label='$t("编码")' prop="serviceCode" width="120" />
            <el-table-column :label='$t("价格")' width="120">
              <template #default="{ row }">¥{{ $t(row.price?.toFixed(2)) }}</template>
            </el-table-column>
            <el-table-column :label='$t("时段")' min-width="200">
              <template #default="{ row }">
                <el-tag v-for="t in row.timeSlots" :key="t" size="small" effect="plain" style="margin-right: 4px">{{ $t(t) }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column :label='$t("状态")' width="100">
              <template #default="{ row }"><StatusTag :status="row.status" /></template>
            </el-table-column>
          </el-table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { Back } from '@element-plus/icons-vue'
import { useAuthStore } from '@/stores/auth'
import ProviderAffiliation from '../../../../../packages/admin-ui/components/ProviderAffiliation.vue'
import ProviderDirectoryTags from '@/components/ProviderDirectoryTags.vue'
import PageHeader from '@/components/PageHeader.vue'
import SubjectAccounts from '@/components/SubjectAccounts.vue'
import TempleStateControl from '@/components/TempleStateControl.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getTempleDetail } from '@/api/temple'
import type { TempleDetail } from '@/types'

const route = useRoute()
const auth = useAuthStore()
const loading = ref(false)
const detail = ref<TempleDetail | null>(null)
const loadError = ref('')

async function loadData() {
  loading.value = true
  loadError.value = ''
  try {
    const data = await getTempleDetail(route.params.id as string)
    if (!data?.temple || typeof data.temple.name !== 'string' || !data.temple.name.trim()) {
      throw new Error('寺院详情数据结构不完整')
    }
    detail.value = {
      ...data,
      images: Array.isArray(data.images) ? data.images : [],
      services: Array.isArray(data.services) ? data.services : []
    }
  } catch (error) {
    detail.value = null
    loadError.value = error instanceof Error ? error.message : '加载寺院详情失败'
  } finally {
    loading.value = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.affiliation-summary{margin:20px 0;max-width:720px}
.detail-wrap {
  display: flex;
  flex-direction: column;
  gap: 16px;
}
.detail-section {
  padding: 20px;
}
.detail-cover {
  width: 100%;
  height: 200px;
  margin-bottom: 16px;
  border-radius: var(--radius-md);
  overflow: hidden;
}
.detail-cover__img,
.detail-cover__fallback {
  width: 100%;
  height: 100%;
}
.detail-cover__fallback {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg-tertiary);
  color: var(--color-accent);
  font-family: var(--font-serif);
  font-weight: var(--type-weight-semibold);
  font-size: var(--type-size-large-metric);
}
.detail-info__name {
  margin: 0 0 12px;
  font-size: var(--type-size-page);
  color: var(--color-text-primary);
}
.detail-info__meta {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 16px;
}
.star {
  color: var(--color-accent);
  font-weight: var(--type-weight-semibold);
}
.detail-info__row {
  font-size: var(--type-size-body);
  color: var(--color-text-secondary);
  line-height: 1.9;
}
.detail-info__row .label {
  color: var(--color-text-tertiary);
}
.section-title {
  font-size: var(--type-size-control);
  font-weight: var(--type-weight-semibold);
  color: var(--color-text-primary);
  margin-bottom: 16px;
  padding-left: 10px;
  border-left: 3px solid var(--color-accent);
}
.gallery {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 12px;
}
.gallery__item {
  position: relative;
}
.gallery__img,
.gallery__fallback {
  width: 100%;
  height: 110px;
  border-radius: var(--radius-sm);
}
.gallery__fallback {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg-tertiary);
  color: var(--color-text-tertiary);
}
.gallery__type {
  position: absolute;
  bottom: 6px;
  left: 6px;
}
</style>
