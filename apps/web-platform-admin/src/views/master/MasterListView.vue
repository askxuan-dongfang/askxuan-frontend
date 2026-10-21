<template>
  <div class="dfx-page">
    <PageHeader :title='$t("法师列表")' :subtitle='$t("全平台法师信息与状态管理")'>
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.regionCode" :placeholder='$t("地区标签")' clearable style="width:140px"><el-option v-for="r in regions" :key="r.code" :label="$t(r.name)" :value="r.code"/></el-select>
      <el-select v-model="query.beliefCode" :placeholder='$t("主信仰")' clearable style="width: 140px">
        <el-option v-for="item in beliefs" :key="item.code" :label="$t(item.name)" :value="item.code" />
      </el-select>
      <el-input v-model="query.templeId" :placeholder='$t("寺院编码")' clearable style="width: 140px" />
      <el-select :disabled="directoryLoading || !!directoryError" v-model="query.traditionCode" :placeholder='$t("标准宗派 / 信俗")' :aria-label='$t("标准宗派 / 信俗")' clearable style="width: 180px">
        <el-option v-for="tag in traditions" :key="tag.code" :label="$t(tag.name)" :value="tag.code" />
        <el-option v-if="query.traditionCode && !traditions.some(tag=>tag.code===query.traditionCode)" :value="query.traditionCode" :label="query.traditionCode" />
      </el-select>
      <el-input v-model="query.sect" :placeholder='$t("历史宗派文字（可选）")' clearable style="width: 180px" />
      <el-button type="primary" @click="router.push('/master/create')">{{ $t("+ 新增独立执业大师") }}</el-button>
            <el-button type="primary" :icon="Search" @click="onSearch">{{ $t("查询") }}</el-button>
      <el-button :icon="RefreshLeft" @click="onReset">{{ $t("重置") }}</el-button>
    </div>
    <p v-if="directoryError" role="alert" class="directory-source-note">{{ $t(directoryError) }} <el-button link @click="loadDirectory">{{ $t('重新加载') }}</el-button></p>
    <p class="directory-source-note">{{ $t("筛选使用完整标准目录，不随当前分页或搜索结果减少；宗派文字仅作为补充资料。") }}</p>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column :label='$t("法师")' min-width="200">
          <template #default="{ row }">
            <div class="master-cell">
              <el-avatar :size="40" :src="row.avatar">{{ $t(row.dharmaName?.slice(0, 1)) }}</el-avatar>
              <div>
                <div class="master-cell__name">{{ $t(row.dharmaName) }}<span class="master-cell__lay">（{{ $t(row.layName) }}）</span></div>
                <div class="master-cell__id">{{ $t(row.id) }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column :label='$t("管理方")' width="110">
          <template #default="{ row }">
            <el-tag :type="row.manageBy === 'platform' ? 'success' : 'info'" size="small">
              {{ $t((row.manageBy === 'platform' ? $t('独立执业') : $t('寺庙绑定'))) }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column :label='$t("所属寺院")' prop="templeName" width="150" />
        <el-table-column :label='$t("职位")' prop="position" width="100" />
        <el-table-column :label='$t("标准宗派 / 信俗")' min-width="160"><template #default="{row}"><el-tag v-for="code in row.traditionCodes || []" :key="code" size="small" style="margin:2px 4px 2px 0">{{ $t(traditionName(code)) }}<small v-if="!directoryTags.some(tag=>tag.code===code&&normalizeBelief(tag.beliefCode||'')===normalizeBelief(row.beliefCode))">{{ $t('（历史关联，需核对）') }}</small></el-tag><span v-if="!row.traditionCodes?.length" class="muted">{{ $t('未关联') }}</span></template></el-table-column>
        <el-table-column :label='$t("宗派补充说明")' prop="sect" min-width="130" />
        <el-table-column :label='$t("类型")' prop="type" width="80" />
        <el-table-column :label='$t("专长")' min-width="160">
          <template #default="{ row }">
            <el-tag v-for="s in row.specialties" :key="s" size="small" effect="plain" style="margin-right: 4px">{{ $t(s) }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column :label='$t("可提供服务")' min-width="150">
          <template #default="{ row }">
            <el-tag v-for="t in row.serviceTags || []" :key="t.serviceCode" size="small" effect="plain" style="margin-right: 4px">
              {{ $t((serviceNameMap[t.serviceCode] || t.serviceCode)) }} ¥{{ $t(t.price) }}
            </el-tag>
            <span v-if="!(row.serviceTags || []).length" class="master-cell__id">{{ $t("未配置") }}</span>
          </template>
        </el-table-column>
        <el-table-column :label='$t("评分")' width="80">
          <template #default="{ row }"><span class="star">★ {{ $t(row.rating?.toFixed(1)) }}</span></template>
        </el-table-column>
        <el-table-column :label='$t("即时咨询")' width="130">
          <template #default="{ row }">
            <div>{{ $t((row.consultEnabled ? ($t("¥") + String(row.consultFee) + $t("")) : $t('未开放'))) }}</div>
            <div class="master-cell__id">{{ $t(row.consultValidHours) }}{{ $t("小时") }}</div>
          </template>
        </el-table-column>
        <el-table-column :label='$t("认证")' width="100">
          <template #default="{ row }"><StatusTag :status="row.authStatus" /></template>
        </el-table-column>
		<el-table-column :label='$t("上架")' width="90">
		  <template #default="{ row }"><StatusTag :status="row.shelfStatus" /></template>
		</el-table-column>
		<el-table-column :label='$t("平台状态")' width="100">
		  <template #default="{ row }"><StatusTag :status="row.platformStatus" /></template>
		</el-table-column>
        <el-table-column :label='$t("地区标签")' min-width="165"><template #default="{row}"><span>{{$t((row.regionName || $t('未设置')))}}</span><ProviderRegionSelect kind="master" :id="row.id" :name="row.dharmaName" :code="row.regionCode" :inherited="row.regionInherited" :temple-bound="row.manageBy==='temple'" @updated="loadData"/></template></el-table-column>
        <el-table-column :label='$t("操作")' width="280" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="router.push(`/master/detail/${row.id}`)">{{ $t("详情/编辑") }}</el-button>
            <el-button link type="primary" @click="openConsult(row)">{{ $t("咨询配置") }}</el-button>
            <el-dropdown @command="(cmd: string) => onStatus(row, cmd)">
              <el-button link type="warning">{{ $t("状态") }}<el-icon><ArrowDown /></el-icon></el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="normal">{{ $t("设为正常") }}</el-dropdown-item>
                  <el-dropdown-item command="banned">{{ $t("封禁法师") }}</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </DataTable>
    </div>

    <el-dialog v-model="consultVisible" :title='$t("即时咨询配置")' width="460px" append-to-body>
      <el-form label-width="110px">
        <el-form-item :label='$t("开放咨询")'><el-switch v-model="consultForm.consultEnabled" /></el-form-item>
        <el-form-item :label='$t("咨询费")'><el-input-number v-model="consultForm.consultFee" :min="1" :max="9999" :precision="2" /></el-form-item>
        <el-form-item :label='$t("有效时长")'><el-input-number v-model="consultForm.consultValidHours" :min="1" :max="720" /><span class="unit">{{ $t("小时") }}</span></el-form-item>
        <el-form-item :label='$t("承诺首响")'><el-input-number v-model="consultForm.consultResponseMinutes" :min="1" :max="1440" /><span class="unit">{{ $t("分钟") }}</span></el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="consultVisible = false" data-quiet-action="cancel">{{ $t("取消") }}</el-button>
        <el-button type="primary" :loading="consultSaving" @click="saveConsult">{{ $t("保存") }}</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import { isAdminSessionExpired } from '@/api/client'
import { useRouter } from 'vue-router'
const router = useRouter()
import { ref, reactive, onMounted, computed } from 'vue'
import { Search, Refresh, RefreshLeft, ArrowDown } from '@element-plus/icons-vue'

import ProviderRegionSelect from '@/components/ProviderRegionSelect.vue'
import {getRegions,type RegionTag} from '@/api/regions'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getMasterList, updateMasterStatus, updateMasterConsultation, getServiceTypes } from '@/api/master'
import { beliefOptions as standardBeliefs, normalizeBelief } from '../../../../../packages/admin-ui/affiliation'
import { getPublicDirectoryTags, type DirectoryTag } from '@/api/directoryTags'
import type { Master } from '@/types'

const beliefs = standardBeliefs
const directoryTags=ref<DirectoryTag[]>([])
const directoryLoading=ref(false),directoryError=ref('')
async function loadDirectory(){directoryLoading.value=true;directoryError.value='';try{directoryTags.value=(await getPublicDirectoryTags()).list||[]}catch(error){directoryError.value='标准宗派目录加载失败，请重试'}finally{directoryLoading.value=false}}
const serviceNameMap = ref<Record<string, string>>({})
const loading = ref(false)
const list = ref<Master[]>([])
const total = ref(0)
const regions=ref<RegionTag[]>([])
onMounted(async()=>{regions.value=(await getRegions()).list||[]})
const query = reactive({ regionCode:'', beliefCode: '', traditionCode: '', templeId: '', sect: '', type: '', page: 1, size: 20 })
const consultVisible = ref(false)
const consultSaving = ref(false)
const consultMasterId = ref('')
const consultForm = reactive({ consultEnabled: true, consultFee: 39, consultValidHours: 72, consultResponseMinutes: 30 })

async function loadData() {
  loading.value = true
  try {
    const res = await getMasterList(query)
    list.value = res.list || []
    total.value = res.total || 0
  } catch (e: any) { if (isAdminSessionExpired(e)) return;
    list.value = []
    total.value = 0
    ElMessage.error((e?.message || uiText('法师列表加载失败，请稍后重试')))
  } finally {
    loading.value = false
  }
}

const traditions=computed(()=>directoryTags.value.filter(tag=>tag.group==='tradition'&&(!query.beliefCode||normalizeBelief(tag.beliefCode||'')===query.beliefCode||tag.code===query.traditionCode)))
function traditionName(code:string){return directoryTags.value.find(tag=>tag.code===code)?.name||code}

function onSearch() {
  query.page = 1
  loadData()
}
function onReset() {
  query.regionCode=''
  query.beliefCode = ''
  query.traditionCode = ''
  query.templeId = ''
  query.sect = ''
  query.type = ''
  onSearch()
}

async function onStatus(row: Master, status: string) {
  await ElMessageBox.confirm((uiText("确认将法师「") + String(row.dharmaName) + uiText("」") + String((status === 'banned' ? uiText('封禁') : uiText('恢复正常'))) + uiText("？")), uiText('提示'), {
    type: status === 'banned' ? 'warning' : 'info'
  })
  await updateMasterStatus(row.id, status)
  ElMessage.success(uiText('状态已更新'))
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
    ElMessage.success(uiText('即时咨询配置已更新'))
    consultVisible.value = false
    await loadData()
  } finally {
    consultSaving.value = false
  }
}

onMounted(async () => {
  // 筛选器与目录加载失败不阻断法师列表主数据（避免列表页静默空白）
  try {
    const [, catalog] = await Promise.all([
      loadDirectory(),
      getServiceTypes().catch(() => ({ list: [] }))
    ])
    serviceNameMap.value = Object.fromEntries((catalog.list || []).map((s) => [s.code, s.name]))
  } catch {
    // ignore
  }
  await loadData()
})
</script>

<style scoped>
.directory-source-note{margin:-4px 0 16px;color:var(--color-text-tertiary);font-size:12px;line-height:1.7}
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
  font-weight: var(--type-weight-semibold);
  color: var(--color-text-primary);
}
.master-cell__lay {
  font-weight: var(--type-weight-regular);
  color: var(--color-text-tertiary);
  font-size: var(--type-size-caption);
}
.master-cell__id {
  font-size: var(--type-size-caption);
  color: var(--color-text-tertiary);
}
.star {
  color: var(--color-accent);
  font-weight: var(--type-weight-semibold);
}
.unit { margin-left: 8px; color: var(--color-text-tertiary); }
</style>
