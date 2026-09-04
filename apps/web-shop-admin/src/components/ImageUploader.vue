<script setup lang="ts">
import { ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus, UploadFilled } from '@element-plus/icons-vue'
import type { UploadFile, UploadFiles, UploadRequestOptions, UploadUserFile } from 'element-plus'
import client from '@/api/client'

const props = withDefaults(
  defineProps<{
    modelValue?: string | string[]
    multiple?: boolean
    limit?: number
    placeholder?: string
    hint?: string
    action?: string
    maxSizeMB?: number
  }>(),
  {
    modelValue: '',
    multiple: false,
    limit: 8,
    placeholder: '或粘贴图片 URL',
    hint: '支持 JPG、PNG、WebP，单张不超过 10MB。',
    action: '/files/upload',
    maxSizeMB: 10
  }
)

const emit = defineEmits<{
  'update:modelValue': [value: string | string[]]
}>()

const urlInput = ref('')
const fileList = ref<UploadUserFile[]>([])

function modelURLs(value: string | string[] | undefined): string[] {
  if (Array.isArray(value)) return value.filter(Boolean)
  return value ? [value] : []
}

watch(
  () => props.modelValue,
  (value) => {
    fileList.value = modelURLs(value).map((url, index) => ({ name: `image-${index + 1}`, url }))
  },
  { immediate: true }
)

function emitURLs(urls: string[]) {
  emit('update:modelValue', props.multiple ? urls : urls[0] || '')
}

function extractURL(response: unknown): string {
  if (typeof response === 'string') return response
  if (!response || typeof response !== 'object') return ''
  const body = response as Record<string, unknown>
  if (typeof body.url === 'string') return body.url
  if (typeof body.link === 'string') return body.link
  if (body.data && typeof body.data === 'object' && typeof (body.data as Record<string, unknown>).url === 'string') {
    return (body.data as Record<string, string>).url
  }
  return ''
}

function beforeUpload(file: File) {
  if (!file.type.startsWith('image/')) {
    ElMessage.warning('请选择图片文件')
    return false
  }
  if (file.size > props.maxSizeMB * 1024 * 1024) {
    ElMessage.warning(`单张图片不能超过 ${props.maxSizeMB}MB`)
    return false
  }
  return true
}

async function httpRequest(options: UploadRequestOptions) {
  const form = new FormData()
  form.append('file', options.file)
  try {
    const response = await client.post<unknown>(props.action, form, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    const url = extractURL(response)
    if (!url) throw new Error('上传成功但未返回文件地址')
    if (!props.multiple) emitURLs([url])
    options.onSuccess({ url })
    if (!props.multiple) ElMessage.success('上传成功')
  } catch (error) {
    options.onError(error as any)
    ElMessage.warning('上传失败，可手动填写图片 URL')
  }
}

function handleSuccess(response: unknown, file: UploadFile, files: UploadFiles) {
  if (!props.multiple) return
  const url = extractURL(response)
  if (!url) {
    ElMessage.error('上传成功但未返回文件地址')
    return
  }
  file.url = url
  fileList.value = files as UploadUserFile[]
  emitURLs(fileList.value.map((item) => item.url || '').filter(Boolean))
  ElMessage.success('上传成功')
}

function handleRemove(_file: UploadFile, files: UploadFiles) {
  fileList.value = files as UploadUserFile[]
  emitURLs(fileList.value.map((item) => item.url || '').filter(Boolean))
}

function handlePreview(file: UploadFile) {
  if (file.url) window.open(file.url, '_blank', 'noopener,noreferrer')
}

function addManualURL() {
  const url = urlInput.value.trim()
  if (!url) return
  const urls = modelURLs(props.modelValue)
  if (props.multiple && urls.length >= props.limit) {
    ElMessage.warning(`最多 ${props.limit} 张图片`)
    return
  }
  emitURLs(props.multiple ? [...urls, url] : [url])
  urlInput.value = ''
}

function clearSingle() {
  emitURLs([])
}
</script>

<template>
  <div class="aui-image-uploader">
    <template v-if="multiple">
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
        <el-icon aria-hidden="true"><Plus /></el-icon>
        <span class="sr-only">添加图片</span>
      </el-upload>
    </template>
    <template v-else>
      <div v-if="typeof modelValue === 'string' && modelValue" class="aui-image-uploader__preview">
        <img :src="modelValue" alt="已上传图片预览" />
        <el-button class="aui-image-uploader__remove" type="danger" @click="clearSingle">移除图片</el-button>
      </div>
      <el-upload
        v-else
        class="aui-image-uploader__dropzone"
        :show-file-list="false"
        :http-request="httpRequest"
        :before-upload="beforeUpload"
        accept="image/*"
        drag
      >
        <el-icon :size="30" aria-hidden="true"><UploadFilled /></el-icon>
        <div>点击或拖拽上传图片</div>
      </el-upload>
    </template>

    <div class="aui-image-uploader__manual">
      <el-input v-model="urlInput" :placeholder="placeholder" clearable @keyup.enter="addManualURL" />
      <el-button type="primary" plain @click="addManualURL">填入</el-button>
    </div>
    <p class="aui-image-uploader__hint">{{ hint.replace('10MB', `${maxSizeMB}MB`) }}</p>
  </div>
</template>

<style scoped>
.aui-image-uploader {
  width: 100%;
  max-width: 520px;
}
.aui-image-uploader__preview {
  position: relative;
  width: min(100%, 360px);
  aspect-ratio: 3 / 2;
  overflow: hidden;
  border: 1px solid var(--color-border-divider, var(--admin-border, var(--border, #e8e0d8)));
  border-radius: 12px;
  background: var(--color-bg-tertiary, #faf6f0);
}
.aui-image-uploader__preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.aui-image-uploader__remove {
  position: absolute;
  right: 10px;
  bottom: 10px;
}
.aui-image-uploader__dropzone {
  width: min(100%, 360px);
}
.aui-image-uploader__dropzone :deep(.el-upload),
.aui-image-uploader__dropzone :deep(.el-upload-dragger) {
  width: 100%;
}
.aui-image-uploader__dropzone :deep(.el-upload-dragger) {
  min-height: 156px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: var(--color-text-secondary, var(--text-light, #6a5a4a));
  background: var(--color-bg-tertiary, #faf6f0);
  border-radius: 12px;
}
.aui-image-uploader__manual {
  display: flex;
  gap: 8px;
  width: 100%;
  margin-top: 10px;
}
.aui-image-uploader__hint {
  margin: 7px 0 0;
  color: var(--color-text-tertiary, var(--text-light, #8a7a6a));
  font-size: 12px;
}
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
@media (max-width: 480px) {
  .aui-image-uploader__manual { align-items: stretch; flex-direction: column; }
  .aui-image-uploader__manual :deep(.el-button) { min-height: 40px; margin-left: 0; }
}
</style>
