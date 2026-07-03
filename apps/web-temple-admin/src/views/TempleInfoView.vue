<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue'
import { ElMessage, type FormInstance } from 'element-plus'
import { Check, Picture } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getTempleInfo, updateTempleInfo } from '@/api/temple'
import type { Temple } from '@/types'

const formRef = ref<FormInstance>()
const loading = ref(false)
const saving = ref(false)
const temple = ref<Temple | null>(null)

const form = reactive({
  id: '',
  name: '',
  region: '',
  address: '',
  coverImage: '',
  description: ''
})

async function load() {
  loading.value = true
  try {
    const t = await getTempleInfo()
    temple.value = t
    form.id = t.id
    form.name = t.name
    form.region = t.region
    form.address = t.address
    form.coverImage = t.coverImage
    form.description = t.description
  } finally {
    loading.value = false
  }
}

async function handleSave() {
  if (!formRef.value) return
  await formRef.value.validate(async (valid) => {
    if (!valid) return
    saving.value = true
    try {
      const t = await updateTempleInfo({
        id: form.id,
        name: form.name,
        region: form.region,
        address: form.address,
        coverImage: form.coverImage,
        description: form.description
      })
      temple.value = t
      ElMessage.success('寺院信息已保存')
    } finally {
      saving.value = false
    }
  })
}

onMounted(load)
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader title="寺院信息" subtitle="维护寺院基础资料与封面">
      <el-button type="primary" :icon="Check" :loading="saving" @click="handleSave">保存修改</el-button>
    </PageHeader>

    <div class="info-grid">
      <div class="df-card info-form">
        <el-form ref="formRef" :model="form" label-width="92px" label-position="right">
          <el-form-item label="寺院名称" prop="name" required>
            <el-input v-model="form.name" placeholder="请输入寺院名称" />
          </el-form-item>
          <el-form-item label="所在地区">
            <el-input v-model="form.region" placeholder="如 浙江杭州" />
          </el-form-item>
          <el-form-item label="详细地址">
            <el-input v-model="form.address" placeholder="请输入详细地址" />
          </el-form-item>
          <el-form-item label="宗派">
            <el-input :model-value="temple?.sect" disabled />
          </el-form-item>
          <el-form-item label="类型">
            <el-input :model-value="temple?.type" disabled />
          </el-form-item>
          <el-form-item label="运营状态">
            <StatusTag v-if="temple" :status="temple.status" kind="temple" />
            <span v-else>-</span>
          </el-form-item>
          <el-form-item label="寺院评分">
            <el-rate :model-value="temple?.rating ?? 0" disabled show-score />
          </el-form-item>
          <el-form-item label="寺院简介">
            <el-input
              v-model="form.description"
              type="textarea"
              :rows="5"
              maxlength="500"
              show-word-limit
              placeholder="请输入寺院简介"
            />
          </el-form-item>
        </el-form>
      </div>

      <div class="df-card info-cover">
        <div class="cover-title"><el-icon><Picture /></el-icon> 封面图片</div>
        <ImageUploader v-model="form.coverImage" hint="建议尺寸 1200×675，将展示在 C 端寺院详情页" />
        <div v-if="form.coverImage" class="cover-preview-label">当前封面预览：</div>
        <img v-if="form.coverImage" :src="form.coverImage" class="cover-preview" alt="cover" />
      </div>
    </div>
  </div>
</template>

<style scoped>
.info-grid {
  display: grid;
  grid-template-columns: 1.4fr 1fr;
  gap: 16px;
  align-items: start;
}
.info-form,
.info-cover {
  padding: 22px 24px;
}
.cover-title {
  display: flex;
  align-items: center;
  gap: 6px;
  font-family: 'Noto Serif SC', serif;
  font-size: 15px;
  font-weight: 600;
  color: #2a1e1a;
  margin-bottom: 16px;
}
.cover-preview-label {
  font-size: 12px;
  color: #8a7a6a;
  margin: 16px 0 8px;
}
.cover-preview {
  width: 100%;
  max-height: 180px;
  object-fit: cover;
  border-radius: 8px;
  border: 1px solid #e8e0d8;
}
</style>
