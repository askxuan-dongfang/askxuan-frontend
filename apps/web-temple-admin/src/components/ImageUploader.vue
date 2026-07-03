<script setup lang="ts">
import { ref } from 'vue'
import { UploadFilled } from '@element-plus/icons-vue'
import { ElMessage } from 'element-plus'
import type { UploadRequestOptions } from 'element-plus'
import client from '@/api/client'

const props = withDefaults(
  defineProps<{ modelValue?: string; action?: string; hint?: string }>(),
  { modelValue: '', action: '/api/v1/file/upload', hint: '建议尺寸 800×600，单张不超过 2MB' }
)
const emit = defineEmits<{ 'update:modelValue': [val: string] }>()

const uploading = ref(false)
const manualUrl = ref('')

async function httpRequest(options: UploadRequestOptions) {
  const fd = new FormData()
  fd.append('file', options.file)
  uploading.value = true
  try {
    const resp: any = await client.post(props.action, fd, {
      headers: { 'Content-Type': 'multipart/form-data' }
    })
    // 兼容多种返回：string / { url } / { data: { url } }
    const url =
      typeof resp === 'string' ? resp : resp?.url || resp?.data?.url || resp?.link || ''
    if (!url) throw new Error('未获取到图片地址')
    emit('update:modelValue', url)
    ElMessage.success('上传成功')
  } catch {
    ElMessage.warning('上传失败，可手动填写图片 URL')
  } finally {
    uploading.value = false
  }
}

function applyManual() {
  const v = manualUrl.value.trim()
  if (!v) return
  emit('update:modelValue', v)
  manualUrl.value = ''
}
function clearImage() {
  emit('update:modelValue', '')
}
</script>

<template>
  <div class="df-uploader">
    <div v-if="modelValue" class="df-uploader-preview">
      <img :src="modelValue" alt="preview" />
      <div class="df-uploader-mask">
        <span @click="clearImage">移除</span>
      </div>
    </div>
    <el-upload
      v-else
      class="df-uploader-box"
      :show-file-list="false"
      :http-request="httpRequest"
      accept="image/*"
      drag
    >
      <el-icon class="df-uploader-icon"><UploadFilled /></el-icon>
      <div class="df-uploader-text">点击或拖拽上传</div>
      <template #tip>
        <div class="df-uploader-hint">{{ hint }}</div>
      </template>
    </el-upload>
    <div class="df-uploader-manual">
      <el-input
        v-model="manualUrl"
        size="small"
        placeholder="或手动粘贴图片 URL"
        clearable
        @keyup.enter="applyManual"
      >
        <template #append>
          <el-button size="small" @click="applyManual">填入</el-button>
        </template>
      </el-input>
    </div>
  </div>
</template>

<style scoped>
.df-uploader {
  width: 240px;
}
.df-uploader-preview {
  position: relative;
  width: 240px;
  height: 160px;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid #e8e0d8;
}
.df-uploader-preview img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}
.df-uploader-mask {
  position: absolute;
  inset: 0;
  background: rgba(28, 18, 16, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: opacity 0.2s;
  color: #fff;
  font-size: 14px;
  cursor: pointer;
}
.df-uploader-preview:hover .df-uploader-mask {
  opacity: 1;
}
.df-uploader-box {
  width: 240px;
}
.df-uploader-box :deep(.el-upload-dragger) {
  width: 240px;
  height: 160px;
  padding: 16px;
  border-radius: 8px;
  background: #faf6f0;
  border-color: #e8e0d8;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
}
.df-uploader-icon {
  font-size: 30px;
  color: #c45a3c;
}
.df-uploader-text {
  font-size: 13px;
  color: #6a5a4a;
  margin-top: 8px;
}
.df-uploader-hint {
  font-size: 12px;
  color: #9a8a7a;
  margin-top: 6px;
}
.df-uploader-manual {
  margin-top: 8px;
}
</style>
