<template>
  <div class="dfx-page">
    <PageHeader :title="`寺院详情 · ${detail?.temple.name || ''}`" subtitle="寺院基础信息 / 图册 / 服务项目">
      <template #actions>
        <el-button :icon="Back" @click="$router.back()">返回</el-button>
      </template>
    </PageHeader>

    <div v-loading="loading">
      <div v-if="detail" class="detail-wrap">
        <!-- 基础信息 -->
        <div class="dfx-card detail-section">
          <div class="detail-cover">
            <el-image v-if="detail.temple.coverImage" :src="detail.temple.coverImage" fit="cover" class="detail-cover__img">
              <template #error><div class="detail-cover__fallback">寺</div></template>
            </el-image>
            <div v-else class="detail-cover__fallback">寺</div>
          </div>
          <div class="detail-info">
            <h2 class="detail-info__name dfx-serif">{{ detail.temple.name }}</h2>
            <div class="detail-info__meta">
              <StatusTag :status="detail.temple.status" />
              <el-tag size="small" effect="plain">{{ detail.temple.type }}</el-tag>
              <el-tag size="small" effect="plain" type="success">{{ detail.temple.beliefCode }}</el-tag>
              <el-tag size="small" effect="plain" type="warning">{{ detail.temple.sect }}</el-tag>
              <span class="star">★ {{ detail.temple.rating?.toFixed(1) }}</span>
            </div>
            <div class="detail-info__row"><span class="label">寺院编码：</span>{{ detail.temple.id }}</div>
            <div class="detail-info__row"><span class="label">所在地区：</span>{{ detail.temple.region }}</div>
            <div class="detail-info__row"><span class="label">详细地址：</span>{{ detail.temple.address || '-' }}</div>
            <div class="detail-info__row"><span class="label">简介：</span>{{ detail.temple.description || '-' }}</div>
          </div>
        </div>

        <!-- 图册 -->
        <div class="dfx-card detail-section">
          <div class="section-title">寺院图册（{{ detail.images.length }}）</div>
          <div v-if="detail.images.length" class="gallery">
            <div v-for="img in detail.images" :key="img.id" class="gallery__item">
              <el-image :src="img.url" fit="cover" class="gallery__img" :preview-src-list="[img.url]" preview-teleported>
                <template #error><div class="gallery__fallback">图</div></template>
              </el-image>
              <el-tag size="small" effect="dark" class="gallery__type">{{ img.type }}</el-tag>
            </div>
          </div>
          <el-empty v-else description="暂无图片" :image-size="60" />
        </div>

        <!-- 服务项目 -->
        <div class="dfx-card detail-section">
          <div class="section-title">服务项目（{{ detail.services.length }}）</div>
          <el-table :data="detail.services" style="width: 100%">
            <el-table-column label="服务名称" prop="serviceName" min-width="160" />
            <el-table-column label="编码" prop="serviceCode" width="120" />
            <el-table-column label="价格" width="120">
              <template #default="{ row }">¥{{ row.price?.toFixed(2) }}</template>
            </el-table-column>
            <el-table-column label="时段" min-width="200">
              <template #default="{ row }">
                <el-tag v-for="t in row.timeSlots" :key="t" size="small" effect="plain" style="margin-right: 4px">{{ t }}</el-tag>
              </template>
            </el-table-column>
            <el-table-column label="状态" width="100">
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
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getTempleDetail } from '@/api/temple'
import type { TempleDetail } from '@/types'

const route = useRoute()
const loading = ref(false)
const detail = ref<TempleDetail | null>(null)

async function loadData() {
  loading.value = true
  try {
    detail.value = await getTempleDetail(route.params.id as string)
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
  font-weight: 900;
  font-size: 48px;
}
.detail-info__name {
  margin: 0 0 12px;
  font-size: 22px;
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
  font-weight: 600;
}
.detail-info__row {
  font-size: 14px;
  color: var(--color-text-secondary);
  line-height: 1.9;
}
.detail-info__row .label {
  color: var(--color-text-tertiary);
}
.section-title {
  font-size: 15px;
  font-weight: 600;
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
