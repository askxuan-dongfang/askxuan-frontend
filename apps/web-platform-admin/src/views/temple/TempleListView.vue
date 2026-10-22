<template>
  <div class="dfx-page">
    <PageHeader :title='$t("寺院列表")' :subtitle='$t("全平台寺院信息与状态管理")'>
      <template #actions>
        <el-button :icon="Refresh" @click="loadData">{{ $t("刷新") }}</el-button>
      </template>
    </PageHeader>

    <div class="dfx-card filter-bar">
      <el-select v-model="query.regionCode" :placeholder='$t("地区标签")' clearable style="width:140px"><el-option v-for="r in regions" :key="r.code" :label="$t(r.name)" :value="r.code"/></el-select>
      <el-select v-model="query.beliefCode" :placeholder='$t("主信仰")' clearable style="width: 140px">
        <el-option v-for="item in beliefOptions" :key="item.code" :label="$t(item.name)" :value="item.code" />
      </el-select>
      <el-input v-model="query.region" :placeholder='$t("城市或省份")' clearable style="width: 140px" />
      <el-select :disabled="directoryLoading || !!directoryError" v-model="query.traditionCode" :placeholder='$t("标准宗派 / 信俗")' :aria-label='$t("标准宗派 / 信俗")' clearable style="width: 180px">
        <el-option v-for="tag in traditions" :key="tag.code" :label="$t(tag.name)" :value="tag.code" />
        <el-option v-if="query.traditionCode && !traditions.some(tag=>tag.code===query.traditionCode)" :value="query.traditionCode" :label="query.traditionCode" />
      </el-select>
      <el-input v-model="query.sect" :placeholder='$t("历史宗派文字（可选）")' clearable style="width: 180px" />
      <el-button type="primary" :icon="Search" @click="onSearch">{{ $t("查询") }}</el-button>
      <el-button :icon="RefreshLeft" @click="onReset">{{ $t("重置") }}</el-button>
    </div>
    <p v-if="directoryError" role="alert" class="directory-source-note">{{ $t(directoryError) }} <el-button link @click="loadDirectory">{{ $t('重新加载') }}</el-button></p>
    <p class="directory-source-note">{{ $t("筛选使用完整标准目录，不随当前分页或搜索结果减少；宗派文字仅作为补充资料。") }}</p>

    <div class="dfx-card table-wrap">
      <DataTable :data="list" :loading="loading" :total="total" v-model:page="query.page" v-model:size="query.size" @change="loadData">
        <el-table-column :label='$t("寺院")' min-width="220">
          <template #default="{ row }">
            <div class="temple-cell">
              <el-image :src="row.coverImage" class="temple-cell__img" fit="cover">
                <template #error><div class="temple-cell__img-fallback">{{ $t("寺") }}</div></template>
              </el-image>
              <div>
                <div class="temple-cell__name">{{ $t(row.name) }}</div>
                <div class="temple-cell__id">{{ $t(row.id) }}</div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column :label='$t("城市或省份")' prop="region" width="110" />
        <el-table-column :label='$t("类型")' prop="type" width="100" />
        <el-table-column :label='$t("主信仰")' width="110">
          <template #default="{ row }">{{ $t(beliefName(row.beliefCode)) }}</template>
        </el-table-column>
        <el-table-column :label='$t("标准宗派 / 信俗")' min-width="160"><template #default="{row}"><el-tag v-for="code in row.traditionCodes || []" :key="code" size="small" style="margin:2px 4px 2px 0">{{ $t(traditionName(code)) }}<small v-if="!directoryTags.some(tag=>tag.code===code&&normalizeBelief(tag.beliefCode||'')===normalizeBelief(row.beliefCode))">{{ $t('（历史关联，需核对）') }}</small></el-tag><span v-if="!row.traditionCodes?.length" class="muted">{{ $t('未关联') }}</span></template></el-table-column>
        <el-table-column :label='$t("宗派补充说明")' prop="sect" min-width="130" />
        <el-table-column :label='$t("评分")' width="90">
          <template #default="{ row }">
            <span class="star">★ {{ $t((row.rating?.toFixed(1) || '-')) }}</span>
          </template>
        </el-table-column>
        <el-table-column :label='$t("上架服务")' width="100" align="center">
          <template #default="{ row }">{{ $t(row.serviceCount) }}</template>
        </el-table-column>
        <el-table-column :label='$t("状态")' width="110">
          <template #default="{ row }">
            <StatusTag :status="row.status" />
          </template>
        </el-table-column>
        <el-table-column :label='$t("地区标签")' min-width="165"><template #default="{row}"><span>{{$t((row.regionName || $t('未设置')))}}</span><ProviderRegionSelect v-if="useAuthStore().roles.includes('platform_super')" kind="temple" :id="row.id" :name="row.name" :code="row.regionCode" :inherited="row.regionInherited" :temple-bound="row.manageBy==='temple'" @updated="loadData"/></template></el-table-column>
        <el-table-column :label='$t("操作")' width="250" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="$router.push(`/temple/detail/${row.id}`)">{{ $t("详情") }}</el-button>
            <el-button v-if="row.status === '待审核' && useAuthStore().roles.includes('platform_super')" link type="success" @click="goToReview(row)">{{ $t("去审核") }}</el-button>
            <el-dropdown v-if="row.status !== '待审核' && (useAuthStore().roles.includes('platform_super') || useAuthStore().access?.permissions.includes('platform.temples.write'))" @command="(cmd: TempleOperationStatus) => onStatus(row, cmd)">
              <el-button link type="warning">{{ $t("状态") }}<el-icon><ArrowDown /></el-icon></el-button>
              <template #dropdown>
                <el-dropdown-menu>
                  <el-dropdown-item command="normal">{{ $t("设为正常") }}</el-dropdown-item>
                  <el-dropdown-item command="recommended">{{ $t("设为推荐") }}</el-dropdown-item>
                  <el-dropdown-item command="banned">{{ $t("封禁寺院") }}</el-dropdown-item>
                </el-dropdown-menu>
              </template>
            </el-dropdown>
          </template>
        </el-table-column>
      </DataTable>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ElMessage, ElMessageBox } from '@/i18n'
import { t as uiText } from '../../../../../packages/localization/language'

import {useAuthStore} from '@/stores/auth'
import { ref, reactive, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Search, Refresh, RefreshLeft, ArrowDown } from '@element-plus/icons-vue'

import ProviderRegionSelect from '@/components/ProviderRegionSelect.vue'
import {getRegions,getPublicRegions,type RegionTag} from '@/api/regions'
import PageHeader from '@/components/PageHeader.vue'
import DataTable from '@/components/DataTable.vue'
import StatusTag from '@/components/StatusTag.vue'
import { getTempleList, updateTempleStatus, type TempleOperationStatus } from '@/api/temple'
import { beliefOptions as standardBeliefs, normalizeBelief } from '../../../../../packages/admin-ui/affiliation'
import { getPublicDirectoryTags, type DirectoryTag } from '@/api/directoryTags'
import type { Temple } from '@/types'

const beliefOptions = standardBeliefs
const directoryTags=ref<DirectoryTag[]>([])
const directoryLoading=ref(false),directoryError=ref('')
async function loadDirectory(){directoryLoading.value=true;directoryError.value='';try{directoryTags.value=(await getPublicDirectoryTags()).list||[]}catch(error){directoryError.value='标准宗派目录加载失败，请重试'}finally{directoryLoading.value=false}}

const loading = ref(false)
const router = useRouter()
const list = ref<Temple[]>([])
const total = ref(0)
const regions=ref<RegionTag[]>([])
onMounted(async()=>{regions.value=(await (useAuthStore().roles.includes('platform_super')?getRegions():getPublicRegions())).list||[]})
const query = reactive({ regionCode:'', beliefCode: '', traditionCode: '', region: '', sect: '', type: '', page: 1, size: 20 })

const traditions=computed(()=>directoryTags.value.filter(tag=>tag.group==='tradition'&&(!query.beliefCode||normalizeBelief(tag.beliefCode||'')===query.beliefCode||tag.code===query.traditionCode)))
function traditionName(code:string){return directoryTags.value.find(tag=>tag.code===code)?.name||code}

function beliefName(code: string) { return beliefOptions.find((item) => item.code === normalizeBelief(code))?.name || code }

async function loadData() {
  loading.value = true
  try {
    const res = await getTempleList(query)
    list.value = res.list || []
    total.value = res.total || 0
  } finally {
    loading.value = false
  }
}


function onSearch() {
  query.page = 1
  loadData()
}
function onReset() {
  query.regionCode=''
  query.beliefCode = ''
  query.traditionCode = ''
  query.region = ''
  query.sect = ''
  query.type = ''
  onSearch()
}

function goToReview(row: Temple) {
  router.push({ path: '/temple/review', query: { templeCode: row.id } })
}

async function onStatus(row: Temple, status: TempleOperationStatus) {
  const actionText = { normal: '设为正常', recommended: '设为推荐', banned: '封禁' }[status] || status
  await ElMessageBox.confirm((uiText("确认将「") + String(row.name) + uiText("」") + String(actionText) + uiText("？")), uiText('提示'), { type: status === 'banned' ? 'warning' : 'info' })
  await updateTempleStatus(row.id, status)
  ElMessage.success(uiText('状态已更新'))
  loadData()
}

onMounted(async () => {
  await Promise.all([loadDirectory(), loadData()])
})
</script>

<style scoped>
.directory-source-note{margin:-4px 0 16px;color:var(--color-text-tertiary);font-size:12px;line-height:1.7}
.filter-bar {
  display: flex;
  gap: 12px;
  align-items: center;
  padding: 16px;
  margin-bottom: 16px;
  flex-wrap: wrap;
}
.table-wrap {
  padding: 16px;
}
.temple-cell {
  display: flex;
  align-items: center;
  gap: 12px;
}
.temple-cell__img,
.temple-cell__img-fallback {
  width: 44px;
  height: 44px;
  border-radius: var(--radius-sm);
  flex-shrink: 0;
}
.temple-cell__img-fallback {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-bg-tertiary);
  color: var(--color-accent);
  font-family: var(--font-serif);
  font-weight: var(--type-weight-semibold);
}
.temple-cell__name {
  font-weight: var(--type-weight-semibold);
  color: var(--color-text-primary);
}
.temple-cell__id {
  font-size: var(--type-size-caption);
  color: var(--color-text-tertiary);
}
.star {
  color: var(--color-accent);
  font-weight: var(--type-weight-semibold);
}
</style>
