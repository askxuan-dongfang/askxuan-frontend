<template>
  <div class="dfx-page">
    <PageHeader :title='$t("举报处理")' :subtitle='$t("全平台内容举报工单处理")'>
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.targetType" :placeholder='$t("举报对象")' clearable style="width: 150px" @change="onSearch">
        <el-option :label='$t("设计素材")' value="design" />
        <el-option :label='$t("评价")' value="comment" />
        <el-option :label='$t("法师")' value="master" />
        <el-option :label='$t("寺院")' value="temple" />
      </el-select>
      <el-select v-model="query.status" :placeholder='$t("处理状态")' clearable style="width: 150px" @change="onSearch">
        <el-option :label='$t("待处理")' value="pending" />
        <el-option :label='$t("已处理")' value="handled" />
        <el-option :label='$t("已驳回")' value="rejected" />
      </el-select>
    </div>

    <div v-if="loadError" class="ax-page-feedback is-error" role="alert">
      <div class="ax-page-feedback__copy">
        <div class="ax-page-feedback__title">{{ $t("举报工单加载失败") }}</div>
        <div class="ax-page-feedback__description">{{ $t("当前结果不可视为无待处理举报，请重新加载。") }}</div>
      </div>
      <el-button :loading="loading" @click="loadData">{{ $t("重新加载") }}</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable class="desktop-table" :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column :label='$t("编号")' prop="id" width="80" />
        <el-table-column :label='$t("举报人")' prop="reporterId" width="110" />
        <el-table-column :label='$t("对象类型")' width="100">
          <template #default="{ row }">{{ $t(targetText(row.targetType)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("对象ID")' prop="targetId" width="120" />
        <el-table-column :label='$t("举报原因")' prop="reason" min-width="180" show-overflow-tooltip />
        <el-table-column :label='$t("证据")' width="120">
          <template #default="{ row }">
            <el-image
              v-for="(url, i) in evidenceUrls(row.evidenceUrls)"
              :key="i"
              :src="url"
              fit="cover"
              class="evidence-img"
              :preview-src-list="evidenceUrls(row.evidenceUrls)"
              :initial-index="i"
              preview-teleported
            >
              <template #error><div class="evidence-img evidence-img--fallback">{{ $t("证") }}</div></template>
            </el-image>
            <span v-if="!evidenceUrls(row.evidenceUrls).length">-</span>
          </template>
        </el-table-column>
        <el-table-column :label='$t("状态")' width="110">
          <template #default="{ row }"><StatusTag :status="row.status" /></template>
        </el-table-column>
        <el-table-column :label='$t("举报时间")' width="170">
          <template #default="{ row }">{{ $t(formatDate(row.createTime)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("操作")' width="140" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === 'pending'" link type="primary" @click="open(row)">{{ $t("处理") }}</el-button>
            <span v-else class="muted">{{ $t("已处理") }}</span>
          </template>
        </el-table-column>
      </DataTable>
      <MobileTaskList v-model:page="query.page" :items="list" :loading="loading" :total="total" :size="query.size" @change="loadData">
        <template #item="{ item: row }">
          <article class="mobile-task-card">
            <div class="mobile-task-card__head"><strong>{{ $t(targetText(row.targetType)) }}{{ $t("举报 #") }}{{ $t(row.id) }}</strong><StatusTag :status="row.status" /></div>
            <div class="mobile-task-card__meta">{{ $t((row.reason || $t('未填写举报原因'))) }}</div>
            <div class="mobile-task-card__meta">{{ $t("举报人 ") }}{{ $t(row.reporterId) }}{{ $t(" · 对象 ") }}{{ $t(row.targetId) }}{{ $t(" · 证据 ") }}{{ $t(evidenceUrls(row.evidenceUrls).length) }}{{ $t(" 项") }}</div>
            <div class="mobile-task-card__foot">
              <span>{{ $t(formatDate(row.createTime)) }}</span>
              <el-button v-if="row.status === 'pending'" type="primary" @click="open(row)">{{ $t("处理") }}</el-button>
              <b v-else>{{ $t("已处理") }}</b>
            </div>
          </article>
        </template>
      </MobileTaskList>
    </div>

    <el-dialog v-model="dialog.visible" :title='$t("处理举报")' width="460px" append-to-body>
      <div class="dialog-info">
        <p><span>{{ $t("对象类型：") }}</span>{{ $t(targetText(dialog.row?.targetType)) }}</p>
        <p><span>{{ $t("举报原因：") }}</span>{{ dialog.row?.reason }}</p>
      </div>
      <el-alert
        :title="$t((dialog.handleResult === 'handled' ? $t('本操作仅将举报工单标记为已处理。内容下架或账号封禁请在对应管理页面执行。') : $t('驳回举报后对象保持当前状态，本次举报将关闭并保留处理记录。')))"
        type="warning"
        :closable="false"
        show-icon
      />
      <el-form label-position="top">
        <el-form-item :label='$t("处理结果")'>
          <el-radio-group v-model="dialog.handleResult">
            <el-radio value="handled">{{ $t("工单已处理") }}</el-radio>
            <el-radio value="rejected">{{ $t("驳回举报") }}</el-radio>
          </el-radio-group>
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialog.visible = false" data-quiet-action="cancel">{{ $t("取消") }}</el-button>
        <el-button type="primary" :loading="dialog.loading" @click="confirm">{{ $t("确认处理") }}</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ElMessage } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { ref, reactive, onMounted } from 'vue'
import { Refresh } from '@element-plus/icons-vue'

import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import MobileTaskList from '@/components/MobileTaskList.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getAuditReports, handleAuditReport } from '@/api/audit'
import { useAuthStore } from '@/stores/auth'
import { formatDate, safeJsonParse } from '@/utils/format'
import type { Report } from '@/types'

const auth = useAuthStore()
const loading = ref(false)
const loadError = ref(false)
const list = ref<Report[]>([])
const total = ref(0)
const query = reactive({ targetType: '', status: '', page: 1, size: 20 })

const dialog = reactive({
  visible: false,
  loading: false,
  row: null as Report | null,
  handleResult: 'handled' as 'handled' | 'rejected',
})

function targetText(t?: string) {
  return { design: '设计素材', comment: '评价', master: '法师', temple: '寺院' }[t || ''] || t || '-'
}

function evidenceUrls(raw: string): string[] {
  return safeJsonParse<string[]>(raw, [])
}

async function loadData() {
  loading.value = true
  loadError.value = false
  try {
    const res = await getAuditReports(query)
    list.value = res.list || []
    total.value = res.total || 0
  } catch {
    loadError.value = true
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  loadData()
}

function open(row: Report) {
  dialog.row = row
  dialog.handleResult = 'handled'
  dialog.visible = true
}

async function confirm() {
  if (!dialog.row) return
  dialog.loading = true
  try {
    await handleAuditReport(dialog.row.id, {
      handlerId: String(auth.userInfo?.userId || '0'),
      handleResult: dialog.handleResult
    })
    ElMessage.success(uiText('处理成功'))
    dialog.visible = false
    loadData()
  } finally {
    dialog.loading = false
  }
}

onMounted(loadData)
</script>

<style scoped>
.filter-bar {
  display: flex;
  gap: 12px;
  padding: 16px;
  margin-bottom: 16px;
}
.table-wrap {
  padding: 16px;
}
.evidence-img {
  width: 36px;
  height: 36px;
  border-radius: var(--radius-sm);
  margin-right: 4px;
}
.evidence-img--fallback {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg-tertiary);
  color: var(--color-text-tertiary);
  font-size: var(--type-size-micro);
}
.muted {
  color: var(--color-text-tertiary);
  font-size: var(--type-size-caption);
}
.dialog-info p {
  margin: 4px 0;
  color: var(--color-text-secondary);
  font-size: var(--type-size-label);
}
.dialog-info span {
  color: var(--color-text-tertiary);
}
</style>
