<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { Delete, Plus, Refresh } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import ImageUploader from '@/components/ImageUploader.vue'
import { createTempleImage, deleteTempleImage, getTempleImages } from '@/api/temple'
import type { TempleImage } from '@/types'

const loading = ref(false)
const saving = ref(false)
const list = ref<TempleImage[]>([])
const dialogVisible = ref(false)
const form = reactive({ url: '', type: 'detail', sort: 0 })

const typeLabels: Record<string, string> = {
  cover: '封面',
  hero: '头图',
  detail: '详情图'
}

async function loadData() {
  loading.value = true
  try {
    const data = await getTempleImages()
    list.value = data.list || []
  } finally {
    loading.value = false
  }
}

function openCreate() {
  form.url = ''
  form.type = 'detail'
  form.sort = list.value.length + 1
  dialogVisible.value = true
}

async function submit() {
  if (!form.url) {
    ElMessage.warning('请先上传图片')
    return
  }
  saving.value = true
  try {
    await createTempleImage(form)
    ElMessage.success('图片已加入寺院图册')
    dialogVisible.value = false
    await loadData()
  } finally {
    saving.value = false
  }
}

async function remove(image: TempleImage) {
  await ElMessageBox.confirm('删除后 C 端将不再展示这张图片，确认继续？', '删除图片', {
    confirmButtonText: '删除',
    cancelButtonText: '取消',
    type: 'warning'
  })
  await deleteTempleImage(image.id)
  ElMessage.success('图片已删除')
  await loadData()
}

onMounted(loadData)
</script>

<template>
  <div class="df-page">
    <PageHeader title="寺院图册" subtitle="维护 C 端寺院详情展示的头图与详情图片">
      <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      <el-button type="primary" :icon="Plus" @click="openCreate">上传图片</el-button>
    </PageHeader>

    <div class="df-card gallery-panel" v-loading="loading">
      <div v-if="list.length" class="gallery-grid">
        <article v-for="image in list" :key="image.id" class="gallery-item">
          <el-image :src="image.url" fit="cover" class="gallery-image" :preview-src-list="[image.url]" preview-teleported>
            <template #error><div class="gallery-fallback">图片无法访问</div></template>
          </el-image>
          <div class="gallery-meta">
            <div>
              <el-tag size="small" effect="plain">{{ typeLabels[image.type] || image.type }}</el-tag>
              <span class="sort">排序 {{ image.sort }}</span>
            </div>
            <el-button circle plain type="danger" :icon="Delete" title="删除图片" @click="remove(image)" />
          </div>
        </article>
      </div>
      <el-empty v-else description="暂无图册图片" />
    </div>

    <el-dialog v-model="dialogVisible" title="上传寺院图片" width="520px">
      <el-form label-position="top">
        <el-form-item label="图片">
          <ImageUploader v-model="form.url" hint="建议横图 1200×800，详情图最多 9 张" />
        </el-form-item>
        <div class="form-row">
          <el-form-item label="展示类型">
            <el-select v-model="form.type" style="width: 180px">
              <el-option label="详情图" value="detail" />
              <el-option label="头图" value="hero" />
              <el-option label="封面图" value="cover" />
            </el-select>
          </el-form-item>
          <el-form-item label="排序">
            <el-input-number v-model="form.sort" :min="0" :max="99" />
          </el-form-item>
        </div>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submit">加入图册</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.gallery-panel { padding: 20px; }
.gallery-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 16px; }
.gallery-item { overflow: hidden; border: 1px solid #e8e0d8; border-radius: 8px; background: #fff; }
.gallery-image, .gallery-fallback { display: flex; width: 100%; height: 180px; align-items: center; justify-content: center; }
.gallery-fallback { color: #8a7a6a; background: #f5f0eb; font-size: 13px; }
.gallery-meta { display: flex; min-height: 52px; padding: 8px 10px; align-items: center; justify-content: space-between; }
.sort { margin-left: 8px; color: #8a7a6a; font-size: 12px; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
@media (max-width: 720px) { .gallery-grid, .form-row { grid-template-columns: 1fr; } }
</style>
