<script setup lang="ts">
import { ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import type { UploadFile, UploadFiles, UploadRequestOptions, UploadUserFile } from 'element-plus'
import client from '@/api/client'

const props = withDefaults(
  defineProps<{
    modelValue: string | string[]
    multiple?: boolean
    limit?: number
    placeholder?: string
  }>(),
  {
    multiple: false,
    limit: 8,
    placeholder: '或粘贴图片 URL'
  }
)

const emit = defineEmits<{
  (e: 'update:modelValue', value: string | string[]): void
}>()

const urlInput = ref('')
const fileList = ref<UploadUserFile[]>([])

function syncFromFileList(urls: string | string[]) {
  const arr = Array.isArray(urls) ? urls : urls ? [urls] : []
  fileList.value = arr.map((url, idx) => ({
    name: `image-${idx + 1}`,
    url
  }))
}

watch(
  () => props.modelValue,
  (val) => syncFromFileList(val),
  { immediate: true }
)

function emitFromList() {
  const urls = fileList.value.map((f) => f.url || '').filter(Boolean)
  if (props.multiple) {
    emit('update:modelValue', urls)
  } else {
    emit('update:modelValue', urls[0] || '')
  }
}

function handleAddUrl() {
  const url = urlInput.value.trim()
  if (!url) return
  if (!props.multiple) {
    fileList.value = [{ name: 'image-1', url }]
  } else {
    if (fileList.value.length >= props.limit) {
      ElMessage.warning(`最多 ${props.limit} 张图片`)
      return
    }
    fileList.value.push({ name: `image-${fileList.value.length + 1}`, url })
  }
  urlInput.value = ''
  emitFromList()
}

function handleRemove(_file: UploadFile, files: UploadFiles) {
  fileList.value = files as UploadUserFile[]
  emitFromList()
}

function handlePreview(file: UploadFile) {
  if (file.url) window.open(file.url, '_blank')
}

async function httpRequest(options: UploadRequestOptions) {
  const form = new FormData()
  form.append('file', options.file)
  try {
    const response = await client.post<{ url: string }>('/files/upload', form, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    options.onSuccess(response)
  } catch (error) {
    options.onError(error as any)
  }
}

function handleSuccess(response: { url?: string }, file: UploadFile, files: UploadFiles) {
  if (!response?.url) {
    ElMessage.error('上传成功但未返回文件地址')
    return
  }
  file.url = response.url
  fileList.value = files as UploadUserFile[]
  emitFromList()
  ElMessage.success('上传成功')
}

function beforeUpload(file: File) {
  if (!file.type.startsWith('image/')) {
    ElMessage.warning('请选择图片文件')
    return false
  }
  if (file.size > 10 * 1024 * 1024) {
    ElMessage.warning('单张图片不能超过 10MB')
    return false
  }
  return true
}
</script>

<template>
  <div class="image-uploader">
    <el-upload
      v-model:file-list="fileList"
      list-type="picture-card"
      accept="image/*"
      :limit="limit"
      :http-request="httpRequest"
      :before-upload="beforeUpload"
      :on-success="handleSuccess"
      :on-remove="handleRemove"
      :on-preview="handlePreview"
    >
      <template #default>
        <el-icon><Plus /></el-icon>
      </template>
    </el-upload>
    <div class="url-row">
      <el-input
        v-model="urlInput"
        size="small"
        :placeholder="placeholder"
        @keyup.enter="handleAddUrl"
      />
      <el-button size="small" type="primary" plain @click="handleAddUrl">添加</el-button>
    </div>
    <p class="tips">支持 JPG、PNG、WebP，单张不超过 10MB。</p>
  </div>
</template>

<style scoped>
.image-uploader {
  width: 100%;
}
.url-row {
  display: flex;
  gap: 8px;
  margin-top: 8px;
  width: 100%;
  max-width: 480px;
}
.tips {
  font-size: 12px;
  color: var(--text-light);
  margin: 8px 0 0;
}
</style>
