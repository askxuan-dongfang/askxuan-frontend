<script setup lang="ts">
import { ref } from 'vue'
import { UploadFilled } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import type { UploadRequestOptions } from 'element-plus'
import client from '@/api/client'

defineProps<{ modelValue?: string }>()
const emit = defineEmits<{ 'update:modelValue': [value: string] }>()
const manualUrl = ref('')

async function upload(options: UploadRequestOptions) {
  if (!options.file.type.startsWith('image/') || options.file.size > 10 * 1024 * 1024) {
    ElMessage.warning('请选择不超过 10MB 的图片')
    options.onError(new Error('invalid image') as any)
    return
  }
  const form = new FormData()
  form.append('file', options.file)
  try {
    const response = await client.post<{ url: string }>('/files/upload', form, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    emit('update:modelValue', response.url)
    options.onSuccess(response)
    ElMessage.success('上传成功')
  } catch (error) {
    options.onError(error as any)
  }
}

function applyManual() {
  const value = manualUrl.value.trim()
  if (!value) return
  emit('update:modelValue', value)
  manualUrl.value = ''
}
</script>

<template>
  <div class="image-uploader">
    <div v-if="modelValue" class="preview">
      <img :src="modelValue" alt="" />
      <el-button class="remove" circle size="small" type="danger" @click="emit('update:modelValue', '')">×</el-button>
    </div>
    <el-upload v-else drag accept="image/*" :show-file-list="false" :http-request="upload">
      <el-icon :size="28"><UploadFilled /></el-icon>
      <div>点击或拖拽上传图片</div>
    </el-upload>
    <div class="manual">
      <el-input v-model="manualUrl" placeholder="或粘贴图片 URL" @keyup.enter="applyManual" />
      <el-button @click="applyManual">填入</el-button>
    </div>
  </div>
</template>

<style scoped>
.image-uploader { width: 100%; }
.preview { position: relative; width: 100%; height: 180px; overflow: hidden; border: 1px solid var(--el-border-color); border-radius: 6px; }
.preview img { width: 100%; height: 100%; object-fit: cover; }
.remove { position: absolute; top: 8px; right: 8px; }
.manual { display: flex; gap: 8px; margin-top: 8px; }
</style>
