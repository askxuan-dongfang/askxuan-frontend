<script setup lang="ts">
// 简易图片上传组件
// MVP 阶段未对接真实文件服务，提供 URL 输入与图片预览；
// 通过 fileList 双向绑定，调用方可以直接保存 URL 列表。
import { ref, watch } from 'vue'
import { ElMessage } from 'element-plus'
import { Plus } from '@element-plus/icons-vue'
import type { UploadFile, UploadFiles, UploadUserFile } from 'element-plus'

const props = withDefaults(
  defineProps<{
    modelValue: string | string[]
    multiple?: boolean
    limit?: number
    /** 占位提示，可用于指示文件服务上传方式 */
    placeholder?: string
  }>(),
  {
    multiple: false,
    limit: 8,
    placeholder: '粘贴图片 URL 或后续接入文件服务'
  }
)

const emit = defineEmits<{
  (e: 'update:modelValue', value: string | string[]): void
}>()

const urlInput = ref('')
const fileList = ref<UploadUserFile[]>([])

// 由 modelValue 同步到 fileList
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

// 由 fileList 同步到 modelValue
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

// 阻止真实上传（避免发请求到 /api/v1/files），仅做本地占位
function handlePreview(file: UploadFile) {
  window.open(file.url, '_blank')
}
</script>

<template>
  <div class="image-uploader">
    <el-upload
      v-model:file-list="fileList"
      list-type="picture-card"
      :auto-upload="false"
      :limit="limit"
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
    <p class="tips">提示：当前为 URL 录入模式，可后续接入 /api/v1/files 真实上传。</p>
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
