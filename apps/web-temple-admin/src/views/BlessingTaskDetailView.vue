<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { ElMessage } from 'element-plus'
import { ArrowLeft } from '@element-plus/icons-vue'
import PageHeader from '@/components/PageHeader.vue'
import StatusTag from '@/components/StatusTag.vue'
import { assignBlessingTask, getBlessingTask } from '@/api/blessing'
import { listMasters } from '@/api/master'
import { useAuthStore } from '@/stores/auth'
import { formatDate } from '@/utils/format'
import type { BlessingTask, Master } from '@/types'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const loading = ref(false)
const assigning = ref(false)
const task = ref<BlessingTask>()
const masters = ref<Master[]>([])
const selectedMaster = ref('')
const taskId = computed(() => Number(route.params.id))
const canAssign = computed(() => task.value?.status === 'dispatched' || task.value?.status === 'rejected')

async function load() {
  loading.value = true
  try {
    const [detail, masterPage] = await Promise.all([
      getBlessingTask(taskId.value),
      listMasters({ templeId: auth.templeId, page: 1, size: 100 })
    ])
    task.value = detail
    masters.value = masterPage.list || []
    selectedMaster.value = detail.masterCode || ''
  } finally {
    loading.value = false
  }
}

async function assign() {
  if (!selectedMaster.value) {
    ElMessage.warning('请选择执行法师')
    return
  }
  assigning.value = true
  try {
    task.value = await assignBlessingTask(taskId.value, selectedMaster.value)
    ElMessage.success('加持任务已分配')
  } finally {
    assigning.value = false
  }
}

onMounted(load)
</script>

<template>
  <div class="df-page" v-loading="loading">
    <PageHeader title="加持任务详情" subtitle="核对订单来源、执行法师与履约凭证">
      <el-button :icon="ArrowLeft" @click="router.push('/blessing-tasks')">返回列表</el-button>
    </PageHeader>

    <template v-if="task">
      <div class="df-card detail-card">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="任务编号">{{ task.taskNo }}</el-descriptions-item>
          <el-descriptions-item label="状态"><StatusTag :status="task.status" kind="blessing" /></el-descriptions-item>
          <el-descriptions-item label="DIY 订单">{{ task.diyOrderNo }}</el-descriptions-item>
          <el-descriptions-item label="寺院编码">{{ task.templeCode }}</el-descriptions-item>
          <el-descriptions-item label="分配时间">{{ formatDate(task.assignTime) }}</el-descriptions-item>
          <el-descriptions-item label="完成时间">{{ formatDate(task.completeTime) }}</el-descriptions-item>
        </el-descriptions>
      </div>

      <div class="df-card assignment-card">
        <h3>执行法师</h3>
        <div class="assignment-row">
          <el-select v-model="selectedMaster" filterable placeholder="选择本寺院法师" :disabled="!canAssign">
            <el-option
              v-for="master in masters"
              :key="master.id"
              :label="`${master.dharmaName} · ${master.position || '法师'}`"
              :value="master.id"
            />
          </el-select>
          <el-button type="primary" :loading="assigning" :disabled="!canAssign" @click="assign">确认分配</el-button>
        </div>
      </div>

      <div class="df-card certificate-card">
        <h3>履约凭证</h3>
        <el-empty v-if="!task.certificateUrls?.length" description="法师完成加持后上传凭证" :image-size="72" />
        <el-image
          v-for="url in task.certificateUrls"
          v-else
          :key="url"
          class="certificate"
          :src="url"
          :preview-src-list="task.certificateUrls"
          fit="cover"
        />
      </div>
    </template>
  </div>
</template>

<style scoped>
.detail-card, .assignment-card, .certificate-card { padding: 20px; margin-bottom: 16px; }
h3 { margin: 0 0 16px; font-size: 16px; color: #2a1e1a; }
.assignment-row { display: grid; grid-template-columns: minmax(260px, 420px) auto; gap: 12px; justify-content: start; }
.certificate { width: 120px; height: 120px; margin-right: 12px; border-radius: 6px; }
</style>
