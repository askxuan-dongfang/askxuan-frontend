<template>
  <div class="dfx-page">
    <PageHeader title="法师列表" subtitle="全平台法师信息与状态管理">
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">刷新</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.beliefCode" placeholder="一级流派" clearable style="width: 140px">
        <el-option v-for="item in beliefs" :key="item.code" :label="item.name" :value="item.code" />
      </el-select>
      <el-input v-model="query.templeId" placeholder="寺院编码" clearable style="width: 140px" />
      <el-select v-model="query.sect" placeholder="宗派" clearable style="width: 140px">
        <el-option v-for="s in sects" :key="s" :label="s" :value="s" />
      </el-select>
      <el-select v-model="query.type" placeholder="类型" clearable style="width: 120px">
        <el-option label="佛教" value="佛教" />
        <el-option label="道教" value="道教" />
      </el-select>
      <el-button type="primary" @click="router.push('/master/create')">+ 新增野生大师</el-button>
            <el-button type="primary" :icon="Search" @click="onSearch">查询</el-button>
      <el-button :icon="RefreshLeft" @click="onReset">重置</el-button>
    </div>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column label="法师" min-width="200">
          <template #default="{ row }">
            <div class="master-cell">
              <el-avatar :size="40" :src="row.avatar">{{ row.dharmaName?.slice(0, 1) }}</el-avatar>
              <div>
                <div class="master-cell__name">{{ row.dharmaName }}<span class="master-cell__lay">（{{ row.layName }}）</span></div>
                <div class="master-cell__id">{{ row.id }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="管理方" width="110">
          <template #default="{ row }">
            <el-tag :type="row.manageBy === 'platform' ? 'success' : 'info'" size="small">
              {{ row.manageBy === 'platform' ? '野生·平台' : '寺庙绑定' }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="所属寺院" prop="templeName" width="150" />
        <el-table-column label="职位" prop="position" width="100" />
        <el-table-column label="宗派" prop="sect" width="90" />
        <el-table-column label="类型" prop="type" width="80" />
        <el-table-column label="专长" min-width="160">
          <template #default="{ row }">
            <el-tag v-for="s in row.specialties" :key="s" size="small" effect="plain" style="margin-right: 4px">{{ s }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="可提供服务" min-width="150">
          <template #default="{ row }">
            <el-tag v-for="t in row.serviceTags || []" :key="t.serviceCode" size="small" effect="plain" style="margin-right: 4px">
              {{ serviceNameMap[t.serviceCode] || t.serviceCode }} ¥{{ t.price }}
            </el-tag>
            <span v-if="!(row.serviceTags || []).length" class="master-cell__id">未配置</span>
          </template>
        </el-table-column>
        <el-table-column label="评分" width="80">
          <template #default="{ row }"><span class="star">★ {{ row.rating?.toFixed(1) }}</span></template>
        </el-table-column>
        <el-table-column label="即时咨询" width="130">
          <template #default="{ row }">
            <div>{{ row.consultEnabled ? `¥${row.consultFee}` : '未开放' }}</div>
            <div class="master-cell__id">{{ row.consultValidHours }}小时</div>
          </template>
        </el-table-column>
        <el-table-column label="认证" width="100">
          <template #default="{ row }"><StatusTag :status="row.authStatus" /></template>
        </el-table-column>
		<el-table-column label="上架" width="90">
		  <template #default="{ row }"><StatusTag :status="row.shelfStatus" /></template>
		</el-table-column>
		<el-table-column label="平台状态" width="100">
		  <template #default="{ row }"><StatusTag :status="row.platformStatus" /></template>
		</el-table-column>
        <el-table-column label="操作" width="280" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="router.push(`/master/detail/${row.id}`)">详情/编辑</el-button>
            <el-button link type="primary" @click="openConsult(row)">咨询配置</el-button>
            <el-dropdown @command="(cmd: string) => onStatus(row, cmd)">
              <el-button link type="warning">状态<el-icon><ArrowDown /></el-icon></el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="normal">设为正常</el-dropdown-item>
                  <el-dropdown-item command="banned">封禁法师</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog v-model="consultVisible" title="即时咨询配置" width="460px">
      <el-form label-width="110px">
        <el-form-item label="开放咨询"><el-switch v-model="consultForm.consultEnabled" /></el-form-item>
        <el-form-item label="咨询费"><el-input-number v-model="consultForm.consultFee" :min="1" :max="9999" :precision="2" /></el-form-item>
        <el-form-item label="有效时长"><el-input-number v-model="consultForm.consultValidHours" :min="1" :max="720" /><span class="unit">小时</span></el-form-item>
        <el-form-item label="承诺首响"><el-input-number v-model="consultForm.consultResponseMinutes" :min="1" :max="1440" /><span class="unit">分钟</span></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="consultVisible = false">取消</el-button>
        <el-button type="primary" :loading="consultSaving" @click="saveConsult">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { useRouter } from 'vue-router'
const router = useRouter()
import { ref, reactive, onMounted } from 'vue'
import { Search, Refresh, RefreshLeft, ArrowDown } from '@element-plus/icons-vue'
import { ElMessage, ElMessageBox } from 'element-plus'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getMasterList, updateMasterStatus, updateMasterConsultation, getServiceTypes } from '@/api/master'
import { taxonomyApi, type BeliefProfile } from '@/api/taxonomy'
import type { Master } from '@/types'

const beliefs = ref<BeliefProfile[]>([])
const sects = ref<string[]>([])
const serviceNameMap = ref<Record<string, string>>({})
const loading = ref(false)
const list = ref<Master[]>([])
const total = ref(0)
const query = reactive({ beliefCode: '', templeId: '', sect: '', type: '', page: 1, size: 20 })
const consultVisible = ref(false)
const consultSaving = ref(false)
const consultMasterId = ref('')
const consultForm = reactive({ consultEnabled: true, consultFee: 39, consultValidHours: 72, consultResponseMinutes: 30 })

async function loadData() {
  loading.value = true
  try {
    const res = await getMasterList(query)
    list.value = res.list || []
    sects.value = [...new Set(list.value.map((item) => item.sect).filter(Boolean))]
    total.value = res.total || 0
  } catch (e: any) {
    list.value = []
    total.value = 0
    ElMessage.error(e?.message || '法师列表加载失败，请稍后重试')
  } finally {
    loading.value = false
  }
}

function onSearch() {
  query.page = 1
  loadData()
}
function onReset() {
  query.beliefCode = ''
  query.templeId = ''
  query.sect = ''
  query.type = ''
  onSearch()
}

async function onStatus(row: Master, status: string) {
  await ElMessageBox.confirm(`确认将法师「${row.dharmaName}」${status === 'banned' ? '封禁' : '恢复正常'}？`, '提示', {
    type: status === 'banned' ? 'warning' : 'info'
  })
  await updateMasterStatus(row.id, status)
  ElMessage.success('状态已更新')
  loadData()
}

function openConsult(row: Master) {
  consultMasterId.value = row.id
  consultForm.consultEnabled = row.consultEnabled
  consultForm.consultFee = row.consultFee || 39
  consultForm.consultValidHours = row.consultValidHours || 72
  consultForm.consultResponseMinutes = row.consultResponseMinutes || 30
  consultVisible.value = true
}

async function saveConsult() {
  consultSaving.value = true
  try {
    await updateMasterConsultation(consultMasterId.value, { ...consultForm })
    ElMessage.success('即时咨询配置已更新')
    consultVisible.value = false
    await loadData()
  } finally {
    consultSaving.value = false
  }
}

onMounted(async () => {
  // 筛选器与目录加载失败不阻断法师列表主数据（避免列表页静默空白）
  try {
    const [beliefResp, catalog] = await Promise.all([
      taxonomyApi.beliefs().catch(() => ({ list: [] })),
      getServiceTypes().catch(() => ({ list: [] }))
    ])
    beliefs.value = beliefResp.list || []
    serviceNameMap.value = Object.fromEntries((catalog.list || []).map((s) => [s.code, s.name]))
  } catch {
    // ignore
  }
  await loadData()
})
</script>

<style scoped>
.filter-bar {
  display: flex;
  gap: 12px;
  padding: 16px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}
.table-wrap {
  padding: 16px;
}
.master-cell {
  display: flex;
  align-items: center;
  gap: 10px;
}
.master-cell__name {
  font-weight: 600;
  color: var(--color-text-primary);
}
.master-cell__lay {
  font-weight: 400;
  color: var(--color-text-tertiary);
  font-size: 12px;
}
.master-cell__id {
  font-size: 12px;
  color: var(--color-text-tertiary);
}
.star {
  color: var(--color-accent);
  font-weight: 600;
}
.unit { margin-left: 8px; color: var(--color-text-tertiary); }
</style>
